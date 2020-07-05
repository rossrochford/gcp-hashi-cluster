#!/bin/bash

PROJECT_ID=$1
CONTAINER_REGISTRY_HOSTNAME=$2
LINUX_USERNAME=$3


docker-credential-gcr config --token-source="env"
docker-credential-gcr configure-docker

gcloud auth print-access-token --project $PROJECT_ID | docker login -u oauth2accesstoken --password-stdin "https://$CONTAINER_REGISTRY_HOSTNAME"


if [ -f "/home/$LINUX_USERNAME/.docker/config.json" ]; then
    cp "/home/$LINUX_USERNAME/.docker/config.json" /root/.docker/config.json
fi
