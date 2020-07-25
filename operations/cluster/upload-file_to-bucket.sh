#!/bin/bash


# validate working directory is: $REPO_DIRECTORY/operations/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *operations && $WORKING_DIRECTORY != *operations/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/operations/'"; exit 1
fi


REPO_DIRECTORY=$(readlink --canonicalize ..)
PROJECT_INFO=$(cat "$REPO_DIRECTORY/build/conf/project-info.json")
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
