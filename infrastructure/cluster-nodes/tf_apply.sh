#!/bin/bash


# validate working directory is: $REPO_DIRECTORY/infrastructure/cluster-nodes/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *infrastructure/cluster-nodes && $WORKING_DIRECTORY != *infrastructure/cluster-nodes/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/infrastructure/cluster-nodes/'"; exit 1
fi

REPO_DIRECTORY=$(readlink --canonicalize ../..)


terraform apply -auto-approve -var-file="$REPO_DIRECTORY/build/conf/project-info.json"
