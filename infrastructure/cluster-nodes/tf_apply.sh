#!/bin/bash


if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


# validate working directory is: $HASHI_REPO_DIRECTORY/infrastructure/cluster-nodes/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *infrastructure/cluster-nodes && $WORKING_DIRECTORY != *infrastructure/cluster-nodes/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/infrastructure/cluster-nodes/'"; exit 1
fi


terraform apply -auto-approve -var-file="$HASHI_REPO_DIRECTORY/build/conf/project-info.json"
