#!/bin/bash


# validate working directory is: $REPO_DIRECTORY/operations/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *operations && $WORKING_DIRECTORY != *operations/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/operations/'"; exit 1
fi


REPO_DIRECTORY=$(readlink --canonicalize ..)
PROJECT_INFO=$(cat "$REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


CONSUL_BOOTSTRAP_TOKEN=$1
GOSSIP_ENCRYPTION_KEY=$2
NEW_INSTANCE_NAMES=$3


if [[ -z $CONSUL_BOOTSTRAP_TOKEN ]]; then
  echo "CONSUL_BOOTSTRAP_TOKEN argument not provided"; exit 1
fi

if [[ -z $GOSSIP_ENCRYPTION_KEY ]]; then
  echo "GOSSIP_ENCRYPTION_KEY argument not provided"; exit 1
fi

if [[ -z $NEW_INSTANCE_NAMES ]]; then
  echo "NEW_INSTANCE_NAMES argument not provided"; exit 1
fi


INSTANCE_NAME="hashi-server-1"
INSTANCE_ZONE=$(gcloud compute instances  describe $INSTANCE_NAME --project $CLUSTER_PROJECT_ID --format="value(zone)")


gcloud compute ssh $INSTANCE_NAME \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --project $CLUSTER_PROJECT_ID \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --command="cd /scripts/operations/ansible; sudo ./initialize_new_hashi_clients.sh $CONSUL_BOOTSTRAP_TOKEN $GOSSIP_ENCRYPTION_KEY $NEW_INSTANCE_NAMES"
