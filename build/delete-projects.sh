#!/bin/bash

UUID=$1

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


DEFAULTS=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-defaults.json")
ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")

VPC_HOST_PROJECT_PREFIX=$(echo $DEFAULTS | jq -r ".vpc_host_project_id_prefix")
VPC_HOST_PROJECT_ID="$VPC_HOST_PROJECT_PREFIX-$UUID"

CLUSTER_PROJECT_PREFIX=$(echo $DEFAULTS | jq -r ".cluster_project_id_prefix")
CLUSTER_PROJECT_ID="$CLUSTER_PROJECT_PREFIX-$UUID"


delete_project () {
  PROJECT_ID=$1
  echo "deleting $PROJECT_ID"

  LIEN_NAME=$(gcloud alpha resource-manager liens list --project=$PROJECT_ID --format="value(NAME)")
  if [[ ! -z $LIEN_NAME ]]; then
    gcloud alpha resource-manager liens delete $LIEN_NAME
  fi

  gcloud projects delete $PROJECT_ID --quiet
}


if [[ $UUID == "all" ]]; then
  PROJECTS=$(gcloud projects list --filter "parent.id=$ORGANIZATION_ID AND parent.type=organization" --format="value(PROJECT_ID)")
  if [[ ! -z $PROJECTS ]]; then
    IFS=$'\n'
    for project in $PROJECTS; do
      delete_project $project
    done
  fi
else
  delete_project $CLUSTER_PROJECT_ID
  delete_project $VPC_HOST_PROJECT_ID
fi


echo "deleting project-info.json"
rm -f "$HASHI_REPO_DIRECTORY/build/conf/project-info.json"

echo "deleting keys"
rm -rf "$HASHI_REPO_DIRECTORY/keys"


echo "removing Terraform state"
rm -rf "$HASHI_REPO_DIRECTORY/infrastructure/cluster-networking/.terraform"
rm -f "$HASHI_REPO_DIRECTORY/infrastructure/cluster-networking/terraform.tfstate"
rm -f "$HASHI_REPO_DIRECTORY/infrastructure/cluster-networking/terraform.tfstate.backup"

rm -rf "$HASHI_REPO_DIRECTORY/infrastructure/cluster-nodes/.terraform"
rm -f "$HASHI_REPO_DIRECTORY/infrastructure/cluster-nodes/terraform.tfstate"
rm -f "$HASHI_REPO_DIRECTORY/infrastructure/cluster-nodes/terraform.tfstate.backup"
