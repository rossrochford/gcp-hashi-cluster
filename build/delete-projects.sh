#!/bin/bash

UUID=$1

WORKING_DIRECTORY=$(readlink --canonicalize ".")

# validate working directory is: $REPO_DIRECTORY/build/
if [[ "$WORKING_DIRECTORY" != *build && "$WORKING_DIRECTORY" != *build/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/build/'"; exit 1
fi

REPO_DIRECTORY=$(readlink --canonicalize ..)
DEFAULTS=$(cat "$REPO_DIRECTORY/build/conf/project-defaults.json")


VPC_HOST_PROJECT_PREFIX=$(echo $DEFAULTS | jq -r ".vpc_host_project_id_prefix")
VPC_HOST_PROJECT_ID="$VPC_HOST_PROJECT_PREFIX-$UUID"


CLUSTER_PROJECT_PREFIX=$(echo $DEFAULTS | jq -r ".cluster_project_id_prefix")
CLUSTER_PROJECT_ID="$CLUSTER_PROJECT_PREFIX-$UUID"


LIEN_NAME=$(gcloud alpha resource-manager liens list --project=$VPC_HOST_PROJECT_ID --format="value(NAME)")

gcloud alpha resource-manager liens delete $LIEN_NAME


gcloud projects delete $VPC_HOST_PROJECT_ID --quiet
gcloud projects delete $CLUSTER_PROJECT_ID --quiet


echo "deleting project-info.json"
rm -f "$REPO_DIRECTORY/build/conf/project-info.json"