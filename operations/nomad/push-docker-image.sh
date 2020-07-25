#!/bin/bash


IMAGE_NAME=$1

if [[ -z $IMAGE_NAME ]]; then
  echo "error: expected argument: IMAGE_NAME"; exit 1
fi


# validate working directory is: $REPO_DIRECTORY/operations/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *operations && $WORKING_DIRECTORY != *operations/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/operations/'"; exit 1
fi

REPO_DIRECTORY=$(readlink --canonicalize ..)
PROJECT_INFO=$(cat "$REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
CONTAINER_REGISTRY_HOSTNAME=$(echo $PROJECT_INFO | jq -r ".container_registry_hostname")
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE=$(echo $PROJECT_INFO | jq -r ".cluster_tf_service_account_ssh_private_key_filepath")


EXPECTED_PREFIX="$CONTAINER_REGISTRY_HOSTNAME/$CLUSTER_PROJECT_ID/"

if [[ $IMAGE_NAME != $EXPECTED_PREFIX* ]]; then
  echo "IMAGE_NAME prefix must be: '$EXPECTED_PREFIX'"; exit 1
fi


get_instance_zone () {
  INSTANCE_ZONE=$(gcloud compute instances list --filter="name:$1" --project=$CLUSTER_PROJECT_ID --format="value(ZONE)" --limit=1)
  if [[ -z $INSTANCE_ZONE ]]; then
    echo "no instance $1 found"; exit 1
  fi
  echo $INSTANCE_ZONE
}

# authenticate docker for private registry and push image
# -----------------------------------------------------------
gcloud auth print-access-token --project $CLUSTER_PROJECT_ID | docker login -u oauth2accesstoken --password-stdin "https://$CONTAINER_REGISTRY_HOSTNAME"

docker push $IMAGE_NAME

if [[ $? != 0 ]]; then
  echo "error: failed to push image"; exit 1
fi


# trigger Nomad clients to pull image and tag with 'nomad/' prefix (runs an ansible script on hashi-server-1)
# ---------------------------------------------------------------------------------------

INSTANCE_NAME="hashi-server-1"

INSTANCE_ZONE=$(get_instance_zone $INSTANCE_NAME)

gcloud compute ssh $INSTANCE_NAME \
  --zone=$INSTANCE_ZONE \
  --tunnel-through-iap \
  --project $CLUSTER_PROJECT_ID \
  --ssh-key-file=$CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --command="cd /scripts/operations/ansible; ./pull_docker_images.sh"


if [[ $? != 0 ]]; then
  echo "error: failure attempting to pulling image on Nomad client nodes"; exit 1
fi


NEW_TAG="nomad/$(echo $IMAGE_NAME | cut -d'/' -f3)"

echo "Success! Your image will be available to Nomad as:  '$NEW_TAG'"
