#!/bin/bash

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


VARS_FILEPATH="$HASHI_REPO_DIRECTORY/build/conf/project-info.json"


# packer build should be run here (ssh key file paths are relative to this)
cd "$HASHI_REPO_DIRECTORY/infrastructure/cluster-networking"

# delete any previous Terraform state
rm -rf ".terraform"
rm -f "terraform.tfstate"
rm -f "terraform.tfstate.backup"


terraform init

terraform apply -auto-approve -var-file=$VARS_FILEPATH
