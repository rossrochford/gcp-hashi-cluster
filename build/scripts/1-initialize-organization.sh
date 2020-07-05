
DEFAULTS=$(cat ./conf/project-defaults.json)

ORGANIZATION_ADMIN_USER=$(echo $DEFAULTS | jq -r ".organization_admin_user_email")
ORGANIZATION_ID=$(echo $DEFAULTS | jq -r ".organization_id")


# Add OrganizationAdmin and Shared VPC Admin roles to ORGANIZATION_ADMIN_USER
# note: for simplicity we're using a single user account for both of these. Nor are we defining a separate "Service Project Admin" (https://cloud.google.com/vpc/docs/provisioning-shared-vpc#networkuseratproject)
# ---------------------------------------------------------------------------------------------

echo "adding Organization Admin and Shared VPC Admin roles"

gcloud organizations add-iam-policy-binding $ORGANIZATION_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/resourcemanager.organizationAdmin"

gcloud organizations add-iam-policy-binding $ORGANIZATION_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/iam.organizationRoleAdmin"

# Assigning the Shared VPC Admin role at the organization level
# based on: https://cloud.google.com/vpc/docs/provisioning-shared-vpc#nominating_shared_vpc_admins_for_the_organization
gcloud organizations add-iam-policy-binding $ORGANIZATION_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/compute.xpnAdmin"

gcloud organizations add-iam-policy-binding $ORGANIZATION_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/resourcemanager.projectIamAdmin"

gcloud organizations add-iam-policy-binding $ORGANIZATION_ID \
  --member="user:$ORGANIZATION_ADMIN_USER" \
  --role="roles/iam.serviceAccountAdmin"



create_role_if_doesnt_exist() {
  NAME=$1
  PERMISSIONS=$2

  CUSTOM_ROLE_EXISTS=$(gcloud iam roles list --organization=$ORGANIZATION_ID --filter="title:$NAME" --format="value(title)")

  if [[ -z "$CUSTOM_ROLE_EXISTS" ]]; then
    # create custom role if it doesn't exist
    gcloud iam roles create $NAME --organization=$ORGANIZATION_ID --permissions=$PERMISSIONS --stage=ALPHA
  fi

}


create_role_if_doesnt_exist "computeAddressUser" "compute.addresses.use"

create_role_if_doesnt_exist "goDiscoverClient" "compute.zones.list,compute.instances.list"
