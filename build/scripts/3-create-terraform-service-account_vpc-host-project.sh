#!/bin/bash

VPC_HOST_PROJECT_ID=$1
SERVICE_ACCOUNT_EMAIL=$2


DEFAULTS=$(cat ./conf/project-defaults.json)

SERVICE_ACCOUNT_NAME=$(echo $DEFAULTS | jq -r ".terraform_vpc_host_project_service_account_name")
ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")


declare -a SERVICE_ACCOUNT_PROJECT_ROLES__VPC_HOST_PROJECT=(
  # so Terraform can create networking resources
  "roles/compute.networkAdmin"
  "roles/compute.securityAdmin"
  "organizations/$ORGANIZATION_ID/roles/computeAddressUser"
)


# Create service account
gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name "${SERVICE_ACCOUNT_NAME}" \
    --project $VPC_HOST_PROJECT_ID


# Add roles on VPC_HOST_PROJECT_ID for service account
# ------------------------------------------------------

for val in ${SERVICE_ACCOUNT_PROJECT_ROLES__VPC_HOST_PROJECT[@]}; do
   gcloud projects add-iam-policy-binding $VPC_HOST_PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role=$val
done


#gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL --member "serviceAccount:$SERVICE_ACCOUNT_EMAIL" --role "roles/iam.serviceAccountUser" --project $VPC_HOST_PROJECT_ID
#gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL --member "serviceAccount:$SERVICE_ACCOUNT_EMAIL" --role "roles/iam.serviceAccountTokenCreator" --project $VPC_HOST_PROJECT_ID


echo "creating credentials keys for service account"

gcloud iam service-accounts keys create "$REPO_DIRECTORY/keys/terraform-service-account-credentials_vpc-host-project.json" \
    --iam-account "${SERVICE_ACCOUNT_EMAIL}" --project $VPC_HOST_PROJECT_ID



