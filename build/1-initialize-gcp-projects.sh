#!/bin/bash

DEFAULTS=$(cat ./conf/project-defaults.json)


ORGANIZATION_ADMIN_USER=$(echo $DEFAULTS | jq -r ".organization_admin_user_email")
ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")
BILLING_ACCOUNT=$(echo $DEFAULTS | jq -r ".billing_account_id")

REGION=$(echo $DEFAULTS | jq -r ".region")
ZONES_ALLOWED=$(cat "./conf/gcp-locations.json" | jq -r ".zones_by_region[\"$REGION\"]")

# Set the HTTP-basic-auth password for the Traefik, Consul and Nomad web dashboards
DASHBOARDS_USERNAME=$(echo $DEFAULTS | jq -r ".dashboards_username")
DASHBOARDS_PASSWORD=$(echo $DEFAULTS | jq -r ".dashboards_password")
DASHBOARDS_AUTH=$(htpasswd -bn $DASHBOARDS_USERNAME $DASHBOARDS_PASSWORD)

CONTAINER_REGISTRY_HOSTNAME=$(cat "./conf/gcp-locations.json" | jq -r ".container_registry_hosts_by_region[\"$REGION\"]")

DOMAIN_NAME=$(echo $DEFAULTS | jq -r ".domain_name")
SUB_DOMAINS="[ \"traefik.$DOMAIN_NAME\", \"consul.$DOMAIN_NAME\", \"nomad.$DOMAIN_NAME\" ]"

SHARED_VPC_NETWORK_NAME=$(echo $DEFAULTS | jq -r ".shared_vpc_network_name")


CLUSTER_SUBNET_NAME=$(echo $DEFAULTS | jq -r ".cluster_subnet_name")
CLUSTER_SUBNET_IP_RANGE=$(echo $DEFAULTS | jq -r ".cluster_subnet_ip_range")


NUM_TRAEFIK_SERVERS=$(echo $DEFAULTS | jq -r ".num_traefik_servers")
TRAEFIK_SERVER_SIZE=$(echo $DEFAULTS | jq -r ".traefik_server_size")

NUM_HASHI_SERVERS=$(echo $DEFAULTS | jq -r ".num_hashi_servers")
HASHI_SERVER_SIZE=$(echo $DEFAULTS | jq -r ".hashi_server_size")

NUM_HASHI_CLIENTS=$(echo $DEFAULTS | jq -r ".num_hashi_clients")
HASHI_CLIENT_SIZE=$(echo $DEFAULTS | jq -r ".hashi_client_size")

NUM_VAULT_SERVERS=$(echo $DEFAULTS | jq -r ".num_vault_servers")
VAULT_SERVER_SIZE=$(echo $DEFAULTS | jq -r ".vault_server_size")


WORKING_DIRECTORY=$(readlink --canonicalize ".")


# Validate input arguments
# ---------------------------------------------------------------

# validate working directory
if [[ "$WORKING_DIRECTORY" != *build && "$WORKING_DIRECTORY" != *build/ ]]; then
  echo "error: working directory must be 'gcp-hashi-cluster/build/'"; exit 1
fi

# validate user email
USER_EXISTS=$(gcloud auth list  --filter-account=$ORGANIZATION_ADMIN_USER --format="value(ACCOUNT)")
if [[ -z $USER_EXISTS ]]; then
  echo "user $ORGANIZATION_ADMIN_USER not found"; exit 1
fi

# validate ORGANIZATION_ADMIN_USER is logged in
USER_LOGGED_IN=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
if [[ $USER_LOGGED_IN != $ORGANIZATION_ADMIN_USER ]]; then
  echo "you are not logged in as $ORGANIZATION_ADMIN_USER"; exit 1
fi

# validate organization ID
ORGANIZATION_EXISTS=$(gcloud organizations list --filter="ID:$ORGANIZATION_ID" --format="value(ID)")
if [[ -z $ORGANIZATION_EXISTS ]]; then
  echo "organization $ORGANIZATION_ID not found"; exit 1
fi

# validate region
REGION_VALID=$(cat "./conf/gcp-locations.json" | jq ".regions | contains([\"$REGION\"])")
if [[ $REGION_VALID != "true" ]]; then echo "error: invalid region: $REGION"; exit 1; fi


# validate domain does not start with "http" or "www."
if [[ "$DOMAIN_NAME" =~ ^http.* || "$DOMAIN_NAME" =~ ^www.* ]]; then
    echo "error: domain_name starts with http or www."; exit 1
fi


if [[ "$NUM_HASHI_SERVERS" != "3" && "$NUM_HASHI_SERVERS" != "5" && "$NUM_HASHI_SERVERS" != "7" ]]; then
  echo "error: 'num_hashi_servers' must be 3, 5 or 7"; exit 1
fi


export REPO_DIRECTORY=$(readlink --canonicalize ..)

PROJECT_INFO_FILEPATH="$REPO_DIRECTORY/build/conf/project-info.json"

# remove any existing project-info.json file
rm -rf $PROJECT_INFO_FILEPATH


# set names for projects, service account
# -------------------------------------------------

UUID=$(uuidgen)
UUID=${UUID:0:13}

echo ""
echo "uuid: $UUID"
echo ""


PREFIX=$(echo $DEFAULTS | jq -r ".vpc_host_project_id_prefix")
VPC_HOST_PROJECT_ID="$PREFIX-$UUID"

PREFIX=$(echo $DEFAULTS | jq -r ".cluster_project_id_prefix")
CLUSTER_PROJECT_ID="$PREFIX-$UUID"

if [[ ${#VPC_HOST_PROJECT_ID} > 30 || ${#CLUSTER_PROJECT_ID} > 30 ]]; then
  echo "error: project ids must have length <= 30"; exit 1
fi

VPC_HOST_PROJECT_TF_SA_NAME=$(echo $DEFAULTS | jq -r ".terraform_vpc_host_project_service_account_name")
VPC_HOST_PROJECT_TF_SA_EMAIL="${VPC_HOST_PROJECT_TF_SA_NAME}@${VPC_HOST_PROJECT_ID}.iam.gserviceaccount.com"

VPC_HOST_PROJECT_TF_SA_CREDENTIALS_FILE="$REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_vpc_host_project_credentials_filename")"


CLUSTER_PROJECT_TF_SA_NAME=$(echo $DEFAULTS | jq -r ".terraform_cluster_project_service_account_name")
CLUSTER_PROJECT_TF_SA_EMAIL="${CLUSTER_PROJECT_TF_SA_NAME}@${CLUSTER_PROJECT_ID}.iam.gserviceaccount.com"

CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE="$REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_cluster_project_credentials_filename")"
CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE="$REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_cluster_project_ssh_key_name").pub"
CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE="$REPO_DIRECTORY/keys/$(echo $DEFAULTS | jq -r ".terraform_cluster_project_ssh_key_name")"


CLUSTER_PROJECT_VM_SA_NAME=$(echo $DEFAULTS | jq -r ".vm_cluster_project_service_account_name")
CLUSTER_PROJECT_VM_SA_EMAIL="${CLUSTER_PROJECT_VM_SA_NAME}@${CLUSTER_PROJECT_ID}.iam.gserviceaccount.com"


PREFIX=$(echo $DEFAULTS | jq -r ".base_image_name_prefix")
BASE_IMAGE_NAME="$PREFIX-$UUID"

PREFIX=$(echo $DEFAULTS | jq -r ".project_bucket_prefix")
PROJECT_BUCKET="$PREFIX-$UUID"  # todo: create bucket

PREFIX=$(echo $DEFAULTS | jq -r ".kms_prefix")
KMS_KEYRING="$PREFIX-keyring-$UUID"
KMS_KEY="$PREFIX-key-$UUID"


rm -rf "$REPO_DIRECTORY/keys"
mkdir -p "$REPO_DIRECTORY/keys"


# create and configure a Shared VPC 'host project' and a 'service project'
# -----------------------------------------------------------------------------

./scripts/1-initialize-organization.sh


./scripts/2-create-projects.sh $VPC_HOST_PROJECT_ID $CLUSTER_PROJECT_ID $CLUSTER_PROJECT_TF_SA_EMAIL


# create service account for vpc host project
./scripts/3-create-terraform-service-account_vpc-host-project.sh $VPC_HOST_PROJECT_ID $VPC_HOST_PROJECT_TF_SA_EMAIL


# create service account for cluster service project
./scripts/4-create-terraform-service-account_cluster-service-project.sh $CLUSTER_PROJECT_ID $VPC_HOST_PROJECT_ID $CLUSTER_PROJECT_TF_SA_EMAIL


# create service account for cluster instances
./scripts/5-create-instance-service-account_cluster-service-project.sh $CLUSTER_PROJECT_ID $CLUSTER_PROJECT_VM_SA_EMAIL


# Add KMS keyring and key for the cluster, this is used to transfer encrypted keys and to auto-unseal Vault
./scripts/6-create-kms-keys.sh $CLUSTER_PROJECT_TF_SA_EMAIL $CLUSTER_PROJECT_ID $REGION $KMS_KEYRING $KMS_KEY


LB_PUBLIC_IP_NAME=$(echo $DEFAULTS | jq -r ".lb_public_ip_name")
LB_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe $LB_PUBLIC_IP_NAME --global --format="get(address)" --project $CLUSTER_PROJECT_ID)


VPC_HOST_PROJECT_TF_SA_ID=$(gcloud iam service-accounts describe $VPC_HOST_PROJECT_TF_SA_EMAIL --format='get(uniqueId)')
VPC_HOST_PROJECT_TF_SA_USERNAME="sa_$VPC_HOST_PROJECT_TF_SA_ID"

CLUSTER_PROJECT_TF_SA_ID=$(gcloud iam service-accounts describe $CLUSTER_PROJECT_TF_SA_EMAIL --format='get(uniqueId)')
CLUSTER_PROJECT_TF_SA_USERNAME="sa_$CLUSTER_PROJECT_TF_SA_ID"


# Generate project-info.json file
# ------------------------------------------------

JSON_STRING1=$( jq -n \
  --arg c $REGION \
  --arg d $ORGANIZATION_ID \
  --arg e $ORGANIZATION_ADMIN_USER \
  --arg f $DOMAIN_NAME \
  --argjson g "$SUB_DOMAINS" \
  --arg h $DASHBOARDS_AUTH \
  --argjson k $NUM_TRAEFIK_SERVERS \
  --argjson r $NUM_HASHI_SERVERS \
  --argjson q $NUM_HASHI_CLIENTS \
  --argjson s $NUM_VAULT_SERVERS \
  --arg t $TRAEFIK_SERVER_SIZE \
  --arg u $HASHI_SERVER_SIZE \
  --arg v $HASHI_CLIENT_SIZE \
  --arg w $VAULT_SERVER_SIZE \
  '{ region: $c, organization_id: $d, organization_admin_email: $e, domain_name: $f, sub_domains: $g, dashboard_auth: $h,
   num_traefik_servers: $k, num_hashi_servers: $r, num_hashi_clients: $q, num_vault_servers: $s,
   traefik_server_size: $t, hashi_server_size: $u, hashi_client_size: $v, vault_server_size: $w }' )


JSON_STRING2=$( jq -n \
  --arg g $UUID \
  --argjson h "$ZONES_ALLOWED" \
  --arg i $BASE_IMAGE_NAME \
  --arg j $PROJECT_INFO_FILEPATH \
  --arg t $LB_PUBLIC_IP_ADDRESS \
  --arg u $CONTAINER_REGISTRY_HOSTNAME \
  --arg aa $PROJECT_BUCKET \
  --arg v $KMS_KEY \
  --arg w $KMS_KEYRING \
  '{ uuid: $g, zones_allowed: $h, base_image_name: $i, project_info_filepath: $j, load_balancer_public_ip_address: $t,
   container_registry_hostname: $u, project_bucket: $aa, kms_encryption_key: $v, kms_encryption_key_ring: $w }' )


JSON_STRING3=$(jq -n \
  --arg a $VPC_HOST_PROJECT_ID \
  --arg j $SHARED_VPC_NETWORK_NAME \
  --arg k $CLUSTER_SUBNET_NAME \
  --arg l $CLUSTER_SUBNET_IP_RANGE \
  --arg m $VPC_HOST_PROJECT_TF_SA_USERNAME \
  --arg n $VPC_HOST_PROJECT_TF_SA_EMAIL \
  --arg o $VPC_HOST_PROJECT_TF_SA_CREDENTIALS_FILE \
  '{ shared_vpc_host_project_id: $a, shared_vpc_network_name: $j, cluster_subnet_name: $k, cluster_subnet_ip_range: $l,
     vpc_service_account_username: $m, vpc_tf_service_account_email: $n, vpc_tf_service_account_credentials_filepath: $o }' )


JSON_STRING4=$(jq -n \
  --arg b $CLUSTER_PROJECT_ID \
  --arg m $CLUSTER_PROJECT_TF_SA_USERNAME \
  --arg n $CLUSTER_PROJECT_TF_SA_EMAIL \
  --arg o $CLUSTER_PROJECT_TF_SA_CREDENTIALS_FILE \
  --arg p $CLUSTER_PROJECT_TF_SA_SSH_PUBLIC_KEY_FILE \
  --arg q $CLUSTER_PROJECT_TF_SA_SSH_PRIVATE_KEY_FILE \
  --arg r $CLUSTER_PROJECT_VM_SA_EMAIL \
  '{ cluster_service_project_id: $b, cluster_tf_service_account_username: $m, cluster_tf_service_account_email: $n,
  cluster_tf_service_account_credentials_filepath: $o, cluster_tf_service_account_ssh_public_key_filepath: $p,
  cluster_tf_service_account_ssh_private_key_filepath: $q, cluster_vm_service_account_email: $r }' )


if [[ $JSON_STRING1 == "null" || $JSON_STRING2 == "null" || $JSON_STRING3 == "null" || $JSON_STRING4 == "null" ]]; then
  echo "error: failed to generate json"
  echo $JSON_STRING1; echo $JSON_STRING2; echo $JSON_STRING3; echo $JSON_STRING4
  exit 0
fi


# combine json data, write and format a json file
# ---------------------------

JSON_STRING_COMBINED=$(echo $JSON_STRING1 $JSON_STRING2 $JSON_STRING3 $JSON_STRING4 | jq -s add)

echo $JSON_STRING_COMBINED >> ./conf/project-info.json

python << END
import json

with open('./conf/project-info.json') as file:
    data = json.loads(file.read())

with open('./conf/project-info.json', 'w') as file:
    string = json.dumps(data, indent=4, separators=(',', ': '))
    file.write(string)
END
