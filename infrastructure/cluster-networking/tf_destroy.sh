#!/bin/bash

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


# validate working directory is: $HASHI_REPO_DIRECTORY/infrastructure/cluster-networking/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *infrastructure/cluster-networking && $WORKING_DIRECTORY != *infrastructure/cluster-networking/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/infrastructure/cluster-networking/'"; exit 1
fi


terraform destroy -auto-approve -var-file="$HASHI_REPO_DIRECTORY/build/conf/project-info.json"
