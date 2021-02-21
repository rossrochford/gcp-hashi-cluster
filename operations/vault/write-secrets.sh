#!/bin/bash

SECRETS_FILEPATH=$1


if [[ (-z $SECRETS_FILEPATH) || (! -f $SECRETS_FILEPATH) ]]; then
  echo "error: SECRETS_FILEPATH argument missing or file doesn't exist"; exit 1
fi

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


PROJECT_INFO=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


get_instance_zone () {
  INSTANCE_ZONE=$(gcloud compute instances list --filter="name:$1" --project=$CLUSTER_PROJECT_ID --format="value(ZONE)" --limit=1)
  if [[ -z $INSTANCE_ZONE ]]; then
    echo "no instance $1 found"; exit 1
  fi
  echo $INSTANCE_ZONE
}

INSTANCE_NAME="vault-server-1"
INSTANCE_ZONE=$(get_instance_zone $INSTANCE_NAME)


gcloud compute scp $SECRETS_FILEPATH \
      "$INSTANCE_NAME:/tmp/new-vault-secrets.json" \
      --project $CLUSTER_PROJECT_ID \
      --zone $INSTANCE_ZONE \
      --tunnel-through-iap \
      --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE


gcloud compute ssh $INSTANCE_NAME \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --project $CLUSTER_PROJECT_ID \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --command="export VAULT_ADDR='http://127.0.0.1:8200'; cd /scripts/utilities; python3 py_utilities/vault_kv.py write-secrets /tmp/new-vault-secrets.json"


gcloud compute ssh $INSTANCE_NAME \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --project $CLUSTER_PROJECT_ID \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --command="rm -f /tmp/new-vault-secrets.json"


# to fetch data run:
#    vault kv get -field=oauth2_key secret/nomad/browserchunk/social-auth-google
