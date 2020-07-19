#!/bin/bash


WORKING_DIRECTORY=$(readlink --canonicalize ".")

# validate working directory is: $REPO_DIRECTORY/build/
if [[ "$WORKING_DIRECTORY" != *build && "$WORKING_DIRECTORY" != *build/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/build/'"; exit 1
fi

export REPO_DIRECTORY=$(readlink --canonicalize ..)

export PROJECT_INFO=$(cat "$REPO_DIRECTORY/build/conf/project-info.json")

CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
REGION=$(echo $PROJECT_INFO | jq -r ".region")
DOMAIN_NAME=$(echo $PROJECT_INFO | jq -r ".domain_name")

KMS_KEY=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key")
KMS_KEYRING=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key_ring")

CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_credentials_filepath")
CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_public_key_filepath")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


INSTANCES=$(gcloud compute instances list --project $CLUSTER_PROJECT_ID --filter="labels.node_type=traefik OR labels.node_type=hashi_server OR labels.node_type=hashi_client OR labels.node_type=vault"  --format="csv[no-heading](NAME,ZONE)")


if [[ -z $INSTANCES ]]; then
  echo "error: no instances found"; exit 1
fi


# create TLS certs for Vault
# -------------------------------------
VAULT_NODE_IPS=$(gcloud compute instances list --project $CLUSTER_PROJECT_ID --filter="labels.node_type=vault" --format="csv[no-heading](INTERNAL_IP)")
VAULT_NODE_IPS=$(echo $VAULT_NODE_IPS | awk 1 ORG=' ')  # replace newlines with spaces

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

done <<< "$INSTANCES"



# we'll use hashi-server-1 to run the Ansible initialization playbooks
INSTANCE_NAME="hashi-server-1"
INSTANCE_ZONE=$(cat "./conf/gcp-locations.json" | jq -r ".zones_by_region[\"$REGION\"][0]")



# Encrypt and zip keys
# ---------------------------------------------------------------------

cd "$REPO_DIRECTORY/keys"
mkdir -p /tmp/ansible-data/collected-keys/

# note: there is a guide for doing this kind of thing, might be worth reading through it: https://cloud.google.com/kms/docs/encrypting-application-data
gcloud kms encrypt --plaintext-file=$CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE --ciphertext-file="/tmp/ansible-data/collected-keys/sa-ssh-key.pub.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project $CLUSTER_PROJECT_ID
gcloud kms encrypt --plaintext-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE --ciphertext-file="/tmp/ansible-data/collected-keys/sa-ssh-key.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project $CLUSTER_PROJECT_ID
gcloud kms encrypt --plaintext-file=$CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE --ciphertext-file="/tmp/ansible-data/collected-keys/sa-credentials.json.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project $CLUSTER_PROJECT_ID

cd /tmp/ansible-data/collected-keys/
zip "/tmp/ansible-data/collected-keys.zip" *.enc
rm -rf "/tmp/ansible-data/collected-keys/"

cd $WORKING_DIRECTORY


hashi_server1_ssh () {
  COMMAND=$1
  gcloud compute ssh $INSTANCE_NAME \
    --zone=$INSTANCE_ZONE \
    --tunnel-through-iap \
    --project $CLUSTER_PROJECT_ID \
    --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
    --command="$COMMAND"
}


# Upload zip file to hashi-server-1
# ---------------------------------------------------------------

echo "uploading credentials and SSH key to $INSTANCE_NAME"

gcloud compute scp "/tmp/ansible-data/collected-keys.zip" "$INSTANCE_NAME:/tmp/collected-keys.zip" \
  --project $CLUSTER_PROJECT_ID \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE


rm -f "/tmp/ansible-data/collected-keys.zip"

hashi_server1_ssh "/scripts/infrastructure/cluster-nodes/scripts/place_collected_keys.sh"



# begin cluster initialization
# -----------------------------------
hashi_server1_ssh "cd /scripts/build/ansible;/scripts/build/ansible/initialize_cluster.sh"


echo ""
echo "waiting for SSL cert to provision and for successful ping from Traefik. This may take up to 15 minutes."
sleep 30

PING_URL="https://$DOMAIN_NAME/ping"

for run in {1..60}
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
