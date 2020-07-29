#!/bin/bash


CLUSTER_PROJECT_ID=$1
VPC_HOST_PROJECT_ID=$2
SERVICE_ACCOUNT_EMAIL=$3

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi

DEFAULTS=$(cat "$HASHI_REPO_DIRECTORY/build/conf/project-defaults.json")

ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")
ORGANIZATION_ADMIN_USER=$(echo $DEFAULTS | jq -r ".organization_admin_user_email")

SERVICE_ACCOUNT_NAME=$(echo $DEFAULTS | jq -r ".terraform_cluster_project_service_account_name")
REGION=$(echo $DEFAULTS | jq -r ".region")


CLUSTER_SUBNET_NAME=$(echo $DEFAULTS | jq -r ".cluster_subnet_name")

CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE="$HASHI_REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_cluster_project_credentials_filename")"
CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE="$HASHI_REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_cluster_project_ssh_key_name").pub"
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE="$HASHI_REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_cluster_project_ssh_key_name")"


# todo: look over these guides for inspiration:
#  https://cloud.google.com/migrate/compute-engine/docs/4.10/how-to/configuring-gcp/configuring-gcp-manually
#  https://cloudacademy.com/course/configuring-gcp-access-and-security/managing-service-accounts/


declare -a SERVICE_ACCOUNT_PROJECT_ROLES__CLUSTER_PROJECT=(

  # so Terraform can create instances and instances can access services (os-login, container images, buckets etc)

  # removed: "roles/compute.networkAdmin"
  # removed: "roles/editor"

  # do we need networkAdmin here for traefik load-balancer resources?

  "roles/compute.loadBalancerAdmin"
  "roles/compute.instanceAdmin"
  "roles/iam.serviceAccountUser"
  "roles/iam.serviceAccountTokenCreator"

  # so instances can ssh to each other as admin (for non-admin use "roles/compute.osLogin")
  "roles/compute.osAdminLogin"
  # Allows for pushing/pulling container images and creating and modifying Cloud Storage buckets/objects
  "roles/storage.admin"
  # Permissions for disks, VM images, and snapshots. Not sure we need this one.
  "roles/compute.storageAdmin"
  # not used but can sometimes be useful to transfer secrets ad-hoc
  "roles/secretmanager.secretAccessor"
  # required for Ansible inventory discovery
  "roles/cloudasset.viewer"

  "roles/logging.logWriter"
  "roles/monitoring.metricWriter"
  "roles/monitoring.viewer"

  # so Terraform can add a google_compute_security_policy (or could use roles/compute.securityAdmin)
  "roles/compute.orgSecurityPolicyAdmin"

  # so the Traefik node can SCP files when the cluster is being initialized, consider creating a separate service account for the Traefik node?
  "roles/iap.tunnelResourceAccessor"

  "organizations/$ORGANIZATION_ID/roles/computeAddressUser"
)


# note: "roles/storage.admin" covers both s3-style Cloud Storage and the container registry. Ideally we'd want instances to
# be able to modify S3 objects but not update container images. I'm not sure how to achieve this. (For a starting point see: https://cloud.google.com/container-registry/docs/access-control#permissions   https://cloud.google.com/storage/docs/access-control/iam-roles )


# Create service account  (note: old approach was to have one of these on the host project and the service project
gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
    --display-name "${SERVICE_ACCOUNT_NAME}" \
    --project $CLUSTER_PROJECT_ID



# Add roles on CLUSTER_PROJECT_ID for service account
# ------------------------------------------------------

for val in ${SERVICE_ACCOUNT_PROJECT_ROLES__CLUSTER_PROJECT[@]}; do
   gcloud projects add-iam-policy-binding $CLUSTER_PROJECT_ID \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role=$val
done



# Grant the admin user permission to act as the service account, for example during os-login SSH. Not 100% about these two commands.
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL --member "user:$ORGANIZATION_ADMIN_USER" --role "roles/iam.serviceAccountUser" --project $CLUSTER_PROJECT_ID
gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL --member "user:$ORGANIZATION_ADMIN_USER" --role "roles/iam.serviceAccountTokenCreator" --project $CLUSTER_PROJECT_ID


# packer needs compute.subnetworks.use and compute.subnetworks.useExternalIp on the subnetwork
gcloud compute networks subnets add-iam-policy-binding \
  $CLUSTER_SUBNET_NAME \
  --region $REGION \
  --project $VPC_HOST_PROJECT_ID \
  --member "serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role "roles/compute.networkAdmin"


echo "creating credentials keys for service account"

# do we need this on BOTH the host and service projects? in which case we need two credential files
gcloud iam service-accounts keys create $CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE \
    --iam-account "${SERVICE_ACCOUNT_EMAIL}" --project $CLUSTER_PROJECT_ID


echo "creating OS-Login SSH key for service account"
ssh-keygen -f $CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE -q -P ""

# not sure about this... (note: old working script uses --project $CLUSTER_PROJECT_ID)
gcloud compute os-login ssh-keys add --key-file=$CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE --project=$CLUSTER_PROJECT_ID  #--impersonate-service-account=$SERVICE_ACCOUNT_EMAIL
