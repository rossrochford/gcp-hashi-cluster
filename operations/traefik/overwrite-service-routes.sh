#!/bin/bash

ROUTES_FILE=$1


if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi

if [[ (-z $ROUTES_FILE) || (! -f $ROUTES_FILE) ]]; then
  echo "error: ROUTES_FILE argument missing or file doesn't exit"; exit 1
fi


PROJECT_INFO=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


INSTANCE_INFO=$(gcloud compute instances list --filter="tags.items:traefik-server" --project=$CLUSTER_PROJECT_ID --format="csv[no-heading](NAME,ZONE)" --limit=1)

if [[ -z $INSTANCE_INFO ]]; then
  echo "no Traefik instances found"; exit 1
fi

INSTANCE_NAME=$(echo $INSTANCE_INFO | cut -d',' -f1)
INSTANCE_ZONE=$(echo $INSTANCE_INFO | cut -d',' -f2)


gcloud compute scp $ROUTES_FILE \
      "$INSTANCE_NAME:/tmp/traefik-service-routes.json" \
      --project $CLUSTER_PROJECT_ID \
      --zone $INSTANCE_ZONE \
      --tunnel-through-iap \
      --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE


gcloud compute ssh $INSTANCE_NAME \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --project $CLUSTER_PROJECT_ID \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --command="cd /scripts/utilities; python3 py_utilities/consul_kv.py overwrite-traefik-service-routes /tmp/traefik-service-routes.json"
