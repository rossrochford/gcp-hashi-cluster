#!/bin/bash

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


WORKING_DIRECTORY=$(readlink --canonicalize ".")

if [[ "$WORKING_DIRECTORY" != *build && "$WORKING_DIRECTORY" != *build/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/build/'"
  exit 1
fi


VARS_FILEPATH="$HASHI_REPO_DIRECTORY/build/conf/project-info.json"

cd "$HASHI_REPO_DIRECTORY/infrastructure/cluster-nodes"

# delete any previous Terraform state
rm -rf ".terraform"
rm -f "terraform.tfstate"
rm -f "terraform.tfstate.backup"

terraform init

terraform apply -auto-approve -var-file=$VARS_FILEPATH
