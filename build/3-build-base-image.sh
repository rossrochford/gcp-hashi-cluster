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

# packer build should be run here (ssh key file paths are relative to this)
cd "$HASHI_REPO_DIRECTORY/build/vm_images"


# uncomment this to enable verbose logging
# export PACKER_LOG=1

packer build -var-file=$VARS_FILEPATH hashi_base.pkr.hcl
