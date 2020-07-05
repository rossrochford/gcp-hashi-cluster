#!/bin/bash


CLUSTER_PROJECT_ID=$1
SERVICE_ACCOUNT_EMAIL=$2

DEFAULTS=$(cat ./conf/project-defaults.json)

ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")
ORGANIZATION_ADMIN_USER=$(echo $DEFAULTS | jq -r ".organization_admin_user_email")

SERVICE_ACCOUNT_NAME=$(echo $DEFAULTS | jq -r ".vm_cluster_project_service_account_name")


declare -a SERVICE_ACCOUNT_ROLES=(

  #"roles/compute.osAdminLogin"
  #"roles/compute.viewer"
  #"roles/compute.networkViewer"

  "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  "roles/logging.logWriter"
  "roles/monitoring.metricWriter"
  "roles/monitoring.viewer"

  # For pulling container images and reading from Cloud storage buckets/objects. Granting objectAdmin is insecure because it allows VMs
  # to push container images. For writeable storage buckets grant 'roles/storage.admin' to individual buckets.
  "roles/storage.objectViewer"

  # required for Ansible inventory discovery
  "roles/cloudasset.viewer"

  # required for go-discovery tool (instead of networkViewer)
  "organizations/$ORGANIZATION_ID/roles/goDiscoverClient"
)


# Create service account
gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name "${SERVICE_ACCOUNT_NAME}" \
    --project $CLUSTER_PROJECT_ID



# Add roles on CLUSTER_PROJECT_ID for service account
# ------------------------------------------------------

for val in ${SERVICE_ACCOUNT_ROLES[@]}; do
   gcloud projects add-iam-policy-binding $CLUSTER_PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role=$val
done


# to list roles on a service account, run:
#   gcloud projects get-iam-policy $CLUSTER_PROJECT_ID --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:$CLUSTER_INSTANCE_SA_EMAIL"
