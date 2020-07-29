#!/bin/bash


if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


PROJECT_INFO=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-info.json")
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")


PROJECT_BUCKET=$(echo $PROJECT_INFO | jq -r ".project_bucket")

LOCAL_FILEPATH=$1
BUCKET_PATH=$2

if [ ! -f $LOCAL_FILEPATH ]; then
    echo "error: $LOCAL_FILEPATH doesn't exist"; exit 1
fi


DESTINATION="gs://$PROJECT_BUCKET/$BUCKET_PATH"
gsutil cp $LOCAL_FILEPATH $DESTINATION


echo "file uploaded to: $DESTINATION"
