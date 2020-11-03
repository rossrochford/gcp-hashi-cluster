#!/bin/bash

REGION=$(metadata_get region)
KMS_KEY=$(metadata_get kms_encryption_key)
KMS_KEYRING=$(metadata_get kms_encryption_key_ring)

mkdir -p /tmp/ansible-data/vault-tls-certs/
mkdir -p /etc/vault.d/certs/

unzip /tmp/ansible-data/vault-tls-certs.zip -d /tmp/ansible-data/vault-tls-certs/

cd /tmp/ansible-data/vault-tls-certs/

if [[ $HOSTING_ENV == "gcp" ]]; then
  gcloud kms decrypt --plaintext-file=vault-ca.crt.pem --ciphertext-file=vault-ca.crt.pem.enc --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
  gcloud kms decrypt --plaintext-file=vault.crt.pem --ciphertext-file=vault.crt.pem.enc --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
  gcloud kms decrypt --plaintext-file=vault.key.pem --ciphertext-file=vault.key.pem.enc --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
fi

# public CA key
mv vault-ca.crt.pem /etc/vault.d/certs/vault_rootCA.pem  # todo: not the final filename
chown vault:vault /etc/vault.d/certs/vault_rootCA.pem

# public key
mv vault.crt.pem /etc/vault.d/certs/certificate.pem
chown vault:vault /etc/vault.d/certs/certificate.pem

# private key
mv vault.key.pem /etc/vault.d/certs/key.pem
chown vault:vault /etc/vault.d/certs/key.pem

rm -rf /tmp/ansible-data/vault-tls-certs/
rm /tmp/ansible-data/vault-tls-certs.zip
