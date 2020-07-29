#!/bin/bash

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi

export PROJECT_INFO=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-info.json")

CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
REGION=$(echo $PROJECT_INFO | jq -r ".region")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


INSTANCE_NAME="hashi-server-1"
INSTANCE_ZONE=$(cat "./conf/gcp-locations.json" | jq -r ".zones_by_region[\"$REGION\"][0]")


echo "cleaning up"

gcloud compute ssh $INSTANCE_NAME \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --project $CLUSTER_PROJECT_ID \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --command="cd /scripts/build/ansible; /scripts/build/ansible/cleanup.sh"
