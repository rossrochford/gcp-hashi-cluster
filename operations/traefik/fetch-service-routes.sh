#!/bin/bash


if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi

PROJECT_INFO=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")
ROUTES_FILEPATH="$HASHI_REPO_DIRECTORY/operations/traefik/traefik-service-routes.json"


INSTANCE_INFO=$(gcloud compute instances list --filter="tags.items:traefik-server" --project=$CLUSTER_PROJECT_ID --format="csv[no-heading](NAME,ZONE)" --limit=1)

if [[ -z $INSTANCE_INFO ]]; then
  echo "no Traefik instances found"; exit 1
fi

INSTANCE_NAME=$(echo $INSTANCE_INFO | cut -d',' -f1)
INSTANCE_ZONE=$(echo $INSTANCE_INFO | cut -d',' -f2)


if [ -f $ROUTES_FILEPATH ]; then
  # make a backup of your local routes file
  cp $ROUTES_FILEPATH "$ROUTES_FILEPATH.bak"
fi


gcloud compute scp "$INSTANCE_NAME:/etc/traefik/traefik-service-routes.json" \
      "$HASHI_REPO_DIRECTORY/operations/traefik/traefik-service-routes.json" \
      --project $CLUSTER_PROJECT_ID \
      --zone $INSTANCE_ZONE \
      --tunnel-through-iap \
      --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE
