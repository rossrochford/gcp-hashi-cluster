#!/bin/bash


if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi


cd "$HASHI_REPO_DIRECTORY/build/scripts/tls-certs"

# remove any previous files
rm -rf /tmp/ansible-data/vault-tls-certs/
rm -rf /tmp/ansible-data/vault-tls-certs.zip
rm -f terraform.tfstate
rm -f terraform.tfstate.backup


mkdir -p /tmp/ansible-data/vault-tls-certs/

CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
REGION=$(echo $PROJECT_INFO | jq -r ".region")
KMS_KEY=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key")
KMS_KEYRING=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key_ring")


# gather vault ip address arguments into a HCL list
vault_ip_addresses='['
for vault_ip in "$@"
do
    vault_ip_addresses="$vault_ip_addresses\"$vault_ip\", "
done
vault_ip_addresses="$vault_ip_addresses]"

echo $vault_ip_addresses


export TF_VAR_ca_public_key_file_path="/tmp/ansible-data/vault-tls-certs/vault-ca.crt.pem"
export TF_VAR_public_key_file_path="/tmp/ansible-data/vault-tls-certs/vault.crt.pem"
export TF_VAR_private_key_file_path="/tmp/ansible-data/vault-tls-certs/vault.key.pem"

export TF_VAR_owner="$USER"  # we'll change file owners to "vault" on our nodes
export TF_VAR_organization_name="untitled organisation"
export TF_VAR_ca_common_name="untitled-org-ca"
export TF_VAR_common_name="untitled-org"

export TF_VAR_dns_names='["vault.service.consul"]'
export TF_VAR_ip_addresses=$vault_ip_addresses


terraform init
terraform apply -auto-approve


gcloud kms encrypt --plaintext-file=$TF_VAR_ca_public_key_file_path --ciphertext-file="$TF_VAR_ca_public_key_file_path.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project=$CLUSTER_PROJECT_ID
gcloud kms encrypt --plaintext-file=$TF_VAR_public_key_file_path --ciphertext-file="$TF_VAR_public_key_file_path.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project=$CLUSTER_PROJECT_ID
gcloud kms encrypt --plaintext-file=$TF_VAR_private_key_file_path --ciphertext-file="$TF_VAR_private_key_file_path.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --project=$CLUSTER_PROJECT_ID


cd /tmp/ansible-data/vault-tls-certs
zip "/tmp/ansible-data/vault-tls-certs.zip" *.enc


rm -rf "/tmp/ansible-data/vault-tls-certs/"


rm -f "$HASHI_REPO_DIRECTORY/build/scripts/tls-certs/terraform.tfstate"
rm -f "$HASHI_REPO_DIRECTORY/build/scripts/tls-certs/terraform.tfstate.backup"
