#!/bin/bash


# validate working directory is: $REPO_DIRECTORY/infrastructure/cluster-networking/
WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ $WORKING_DIRECTORY != *infrastructure/cluster-networking && $WORKING_DIRECTORY != *infrastructure/cluster-networking/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/infrastructure/cluster-networking/'"; exit 1
fi

REPO_DIRECTORY=$(readlink --canonicalize ../..)


terraform destroy -auto-approve -var-file="$REPO_DIRECTORY/build/conf/project-info.json"
