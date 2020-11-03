#!/bin/bash

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


WORKING_DIRECTORY=$(readlink --canonicalize ".")

export PROJECT_INFO=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-info.json")

CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
REGION=$(echo $PROJECT_INFO | jq -r ".region")
DOMAIN_NAME=$(echo $PROJECT_INFO | jq -r ".domain_name")

KMS_KEY=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key")
KMS_KEYRING=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key_ring")


CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_credentials_filepath")
CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_public_key_filepath")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


INSTANCES=$(gcloud compute instances list --project $CLUSTER_PROJECT_ID \
  --filter="labels.node_type=traefik OR labels.node_type=hashi_server OR labels.node_type=hashi_client OR labels.node_type=vault"  \
  --format="csv[no-heading](NAME,ZONE,STATUS,LABELS)")



# validating that instances are alive and initialized
# ---------------------------------------------------

if [[ -z $INSTANCES ]]; then
  echo "error: no instances found"; exit 1
fi

get_startup_status() {
  LABEL_STR=$1
  STATUS=$(python -c "labels=dict([pair.split('=') for pair in \"$LABEL_STR\".split(';')]); print(labels['startup_status'])")
  echo $STATUS
}


while IFS= read -r LINE; do

    INSTANCE_NAME=$(echo $LINE | cut -d',' -f1)
    STATUS=$(echo $LINE | cut -d',' -f3)
    LABELS=$(echo $LINE | cut -d',' -f4)
    STARTUP_STATUS=$(get_startup_status $LABELS)

    if [[ $STARTUP_STATUS == "failed" ]]; then
      echo "$INSTANCE_NAME failed during initialization, exiting"; exit 1
    fi

    if [[ $STATUS == "TERMINATED" ]]; then
      echo "$INSTANCE_NAME is TERMINATED, remove or restart this instance, exiting"; exit 1
    fi

    if [[ $STATUS != "RUNNING" || $STARTUP_STATUS == "initializing" ]]; then
      echo "$INSTANCE_NAME is still initializing, waiting 45s"
      sleep 45
    fi

done <<< "$INSTANCES"



# create TLS certs for Vault
# -------------------------------------
VAULT_NODE_IPS=$(gcloud compute instances list --project $CLUSTER_PROJECT_ID --filter="labels.node_type=vault" --format="csv[no-heading](INTERNAL_IP)")
VAULT_NODE_IPS=$(echo $VAULT_NODE_IPS | awk 1 ORG=' ')  # replace newlines with spaces
export HOSTING_ENV=gcp

./scripts/tls-certs/create_vault_tls_certs.sh $VAULT_NODE_IPS



# copy vault-tls-certs.zip to the other instances
# --------------------------------------------------------

while IFS= read -r LINE; do

    INSTANCE_NAME=$(echo $LINE | cut -d',' -f1)
    ZONE=$(echo $LINE | cut -d',' -f2)

    echo "transferring vault-tls-certs.zip to: $INSTANCE_NAME ($ZONE)"

    gcloud compute scp /tmp/ansible-data/vault-tls-certs.zip \
      "$INSTANCE_NAME:/tmp/ansible-data/vault-tls-certs.zip" \
      --project $CLUSTER_PROJECT_ID \
      --zone $ZONE \
      --tunnel-through-iap \
      --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE

      if [[ $? != 0 ]]; then
        echo "SCP failed, exiting"; exit 1
      fi

done <<< "$INSTANCES"



# we'll use hashi-server-1 to run the Ansible initialization playbooks
INSTANCE_NAME="hashi-server-1"
INSTANCE_ZONE=$(cat "./conf/gcp-locations.json" | jq -r ".zones_by_region[\"$REGION\"][0]")



# Encrypt and zip keys
# ---------------------------------------------------------------------

cd "$HASHI_REPO_DIRECTORY/keys"
mkdir -p /tmp/ansible-data/collected-keys/

# note: there is a guide for doing this kind of thing, might be worth reading through it: https://cloud.google.com/kms/docs/encrypting-application-data
gcloud kms encrypt --plaintext-file=$CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE --ciphertext-file="/tmp/ansible-data/collected-keys/sa-ssh-key.pub.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project $CLUSTER_PROJECT_ID
gcloud kms encrypt --plaintext-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE --ciphertext-file="/tmp/ansible-data/collected-keys/sa-ssh-key.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project $CLUSTER_PROJECT_ID
gcloud kms encrypt --plaintext-file=$CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE --ciphertext-file="/tmp/ansible-data/collected-keys/sa-credentials.json.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project $CLUSTER_PROJECT_ID

cd /tmp/ansible-data/collected-keys/
zip "/tmp/ansible-data/collected-keys.zip" *.enc
rm -rf "/tmp/ansible-data/collected-keys/"

cd $WORKING_DIRECTORY


# Upload zip file to hashi-server-1
# ---------------------------------------------------------------

echo "uploading credentials and SSH key to $INSTANCE_NAME"

gcloud compute scp "/tmp/ansible-data/collected-keys.zip" "$INSTANCE_NAME:/tmp/collected-keys.zip" \
  --project $CLUSTER_PROJECT_ID \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE

if [[ $? != 0 ]]; then
  rm -f "/tmp/ansible-data/collected-keys.zip"
  echo "SCP to $INSTANCE_NAME failed, exiting"; exit 1
fi

rm -f "/tmp/ansible-data/collected-keys.zip"


hashi_server1_ssh () {
  COMMAND=$1
  gcloud compute ssh $INSTANCE_NAME \
    --zone=$INSTANCE_ZONE \
    --tunnel-through-iap \
    --project $CLUSTER_PROJECT_ID \
    --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
    --command="$COMMAND"
}


hashi_server1_ssh "/scripts/infrastructure/cluster-nodes/startup_scripts/place_collected_keys.sh"



# begin cluster initialization
# -----------------------------------
hashi_server1_ssh "cd /scripts/build/ansible;/scripts/build/ansible/initialize_cluster.sh"


echo ""
echo "waiting for SSL cert to provision and for successful ping from Traefik. This may take up to 15 minutes."
sleep 30

PING_URL="https://$DOMAIN_NAME/ping"

for run in {1..70}
do
  echo "attempting request to: $PING_URL"
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}"  $PING_URL)
  if [[ "$STATUS_CODE" == "200" ]]; then
    echo ""
    echo "Ping success! Your cluster is up and running."
    exit 0

  fi
  sleep 15
done

echo "warning: connection attempt timed out"
