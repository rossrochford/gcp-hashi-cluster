#!/bin/bash

VPC_HOST_PROJECT_ID=$1
CLUSTER_PROJECT_ID=$2
CLUSTER_PROJECT_TF_SA_EMAIL=$3

DEFAULTS=$(cat ./conf/project-defaults.json)

ORGANIZATION_ADMIN_USER=$(echo $DEFAULTS | jq -r ".organization_admin_user_email")
ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")
BILLING_ACCOUNT=$(echo $DEFAULTS | jq -r ".billing_account_id")

REGION=$(echo $DEFAULTS | jq -r ".region")


SHARED_VPC_NETWORK_NAME=$(echo $DEFAULTS | jq -r ".shared_vpc_network_name")
CLUSTER_SUBNET_NAME=$(echo $DEFAULTS | jq -r ".cluster_subnet_name")
CLUSTER_SUBNET_IP_RANGE=$(echo $DEFAULTS | jq -r ".cluster_subnet_ip_range")

LB_PUBLIC_IP_NAME=$(echo $DEFAULTS | jq -r ".lb_public_ip_name")


create_project () {
  gcloud projects create $1 --organization=$ORGANIZATION_ID --user-output-enabled false
  sleep 2
  gcloud beta billing projects link $1 --billing-account=$BILLING_ACCOUNT
  sleep 2
  gcloud services enable compute.googleapis.com --project $1
  sleep 30
  # delete default network
  gcloud compute firewall-rules delete default-allow-ssh default-allow-rdp default-allow-internal default-allow-icmp --quiet --project=$1
  gcloud compute networks delete default --quiet --project=$1
}

# Setup Shared VPC and its 'host project'
# ------------------------------------------

create_project $VPC_HOST_PROJECT_ID

gcloud config set project $VPC_HOST_PROJECT_ID

gcloud compute shared-vpc enable $VPC_HOST_PROJECT_ID

VPC_HOST_PROJECT_NUMBER=$(gcloud projects describe $VPC_HOST_PROJECT_ID --format='get(projectNumber)')

# Make org admin user a 'Service Project Admin' with access to all subnets in the vpc host project (https://cloud.google.com/vpc/docs/provisioning-shared-vpc#networkuseratproject)
gcloud projects add-iam-policy-binding $VPC_HOST_PROJECT_ID \
  --member "user:$ORGANIZATION_ADMIN_USER" \
  --role "roles/compute.networkUser"


# Create cluster service project
# -------------------------------
create_project $CLUSTER_PROJECT_ID

CLUSTER_PROJECT_NUMBER=$(gcloud projects describe $CLUSTER_PROJECT_ID --format='get(projectNumber)')


# grants ALL permissions on this project to the org admin user
gcloud projects add-iam-policy-binding $CLUSTER_PROJECT_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/owner"

# allows for logging in as admin (e.g. via SSH)
gcloud projects add-iam-policy-binding $CLUSTER_PROJECT_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/compute.osAdminLogin"

# allows for management of service account keys
gcloud  projects add-iam-policy-binding $CLUSTER_PROJECT_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/iam.serviceAccountKeyAdmin"


# note: consider using the project_services TF module: https://www.terraform.io/docs/providers/google/guides/version_3_upgrade.html#new-config-module-
gcloud services enable \
    cloudresourcemanager.googleapis.com \
    serviceusage.googleapis.com \
    compute.googleapis.com \
    iam.googleapis.com \
    oslogin.googleapis.com \
    cloudbilling.googleapis.com \
    logging.googleapis.com \
    sourcerepo.googleapis.com \
    cloudkms.googleapis.com \
    containerregistry.googleapis.com \
    monitoring.googleapis.com \
    cloudasset.googleapis.com \
    secretmanager.googleapis.com \
    --project $CLUSTER_PROJECT_ID


# created shared network and two subnets, one for each service project
# -------------------------------------------------------------------------


# is 'bgp-routing-mode=global ' correct here?
gcloud compute networks create $SHARED_VPC_NETWORK_NAME \
    --subnet-mode custom \
    --project $VPC_HOST_PROJECT_ID \
    --bgp-routing-mode=global

# note: these are hard-coded but they need not be
gcloud compute networks subnets create $CLUSTER_SUBNET_NAME \
    --network $SHARED_VPC_NETWORK_NAME \
    --range $CLUSTER_SUBNET_IP_RANGE \
    --region $REGION \
    --project $VPC_HOST_PROJECT_ID


# reserve static IP address for Traefik node (note: we don't specify network or subnet here)
gcloud compute addresses create $LB_PUBLIC_IP_NAME --network-tier=PREMIUM --project $CLUSTER_PROJECT_ID --global  # --region=$REGION


# Attach service projects to host project
# --------------------------------------
gcloud compute shared-vpc associated-projects add $CLUSTER_PROJECT_ID --host-project $VPC_HOST_PROJECT_ID



# Grant "roles/compute.networkUser" to the "Google APIs services account" (a special service account on each project) on each service project's subnet. This is necessary for using managed instance groups (https://cloud.google.com/vpc/docs/provisioning-shared-vpc#migs-service-accounts). Also see: https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-shared-vpc#enabling_and_granting_roles
#    - note: this is slightly different to the docs, which suggest granting this on the host project level, effectively applying it to all subnets of the Shared VPC host project (see see: https://cloud.google.com/vpc/docs/provisioning-shared-vpc#migs-service-accounts). Just in case, we'll do this for the admin user.
# ---------------------------------------------------------------


# notice this is on the host project level, similar to the docs
gcloud compute networks subnets add-iam-policy-binding \
  $CLUSTER_SUBNET_NAME \
  --region $REGION \
  --project $VPC_HOST_PROJECT_ID \
  --member "serviceAccount:$CLUSTER_PROJECT_NUMBER@cloudservices.gserviceaccount.com" \
  --role "roles/compute.networkUser"


# adding this just in case
gcloud projects add-iam-policy-binding $VPC_HOST_PROJECT_ID \
    --member "serviceAccount:$VPC_HOST_PROJECT_NUMBER@cloudservices.gserviceaccount.com" \
    --role "roles/compute.networkUser"


# adding this just in case
gcloud projects add-iam-policy-binding $VPC_HOST_PROJECT_ID \
    --member "user:$ORGANIZATION_ADMIN_USER" \
    --role "roles/compute.networkUser"
