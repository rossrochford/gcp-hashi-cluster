#!/bin/bash


WORKING_DIRECTORY=$(readlink --canonicalize ".")

# validate working directory is: $REPO_DIRECTORY/docs/tutorials/flask-redis-counter/count-service
if [[ $WORKING_DIRECTORY != *count-service && $WORKING_DIRECTORY != *count-service/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/docs/tutorials/flask-redis-counter/count-service/'"; exit 1
fi

REPO_DIRECTORY=$(readlink --canonicalize ../../../..)

PROJECT_INFO=$(cat "$REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
CONTAINER_REGISTRY_HOSTNAME=$(echo $PROJECT_INFO | jq -r ".container_registry_hostname")


VERSION_TAG="v0.1"
SERVICE_NAME="count-webserver"


IMAGE_TAG="$CONTAINER_REGISTRY_HOSTNAME/$CLUSTER_PROJECT_ID/$SERVICE_NAME:$VERSION_TAG"

docker build -t $IMAGE_TAG .
