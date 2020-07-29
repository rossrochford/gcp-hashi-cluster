#!/bin/bash


PROJECT_INFO=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info)

CONTAINER_REGISTRY_HOSTNAME=$(echo $PROJECT_INFO | jq -r ".container_registry_hostname")
PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")


gcloud auth print-access-token --project $PROJECT_ID | sudo docker login -u oauth2accesstoken --password-stdin "https://$CONTAINER_REGISTRY_HOSTNAME"

IMAGES=$(gcloud container images list --repository="$CONTAINER_REGISTRY_HOSTNAME/$PROJECT_ID" --format="value(NAME)")

if [[ -z $IMAGES ]]; then
  exit 0
fi


# pull latest version of each image and add a local tag with '-nomad' appended
while IFS= read -r img; do
    LATEST_TAG=$(gcloud container images list-tags $img --format="value(TAGS)" --limit=1)

    if [[ $LATEST_TAG = *","* ]]; then
       # when an image-hash has > 1 tags, a comma-separated list is given, get the last item
       LATEST_TAG=$(echo $LATEST_TAG | grep -o '[^,]*$')
    fi

    IMAGE="$img:$LATEST_TAG"
    docker pull $IMAGE
    NEW_TAG="nomad/$(echo $IMAGE | cut -d'/' -f3)"
    docker tag $IMAGE $NEW_TAG
done <<< "$IMAGES"

# todo: consider adding GCP Container Analysis: https://cloud.google.com/container-registry/docs/get-image-vulnerabilities