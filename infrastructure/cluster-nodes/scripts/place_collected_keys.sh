#!/bin/bash

PROJECT_INFO=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info)

REGION=$(echo $PROJECT_INFO | jq -r ".region")
KMS_KEY=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key")
KMS_KEYRING=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key_ring")


sudo mkdir -p /etc/collected-keys

sudo unzip /tmp/collected-keys.zip -d /etc/collected-keys

cd /etc/collected-keys


sudo gcloud kms decrypt --plaintext-file="./sa-ssh-key.pub" --ciphertext-file="./sa-ssh-key.pub.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION

sudo gcloud kms decrypt --plaintext-file="./sa-ssh-key" --ciphertext-file="./sa-ssh-key.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION

sudo gcloud kms decrypt --plaintext-file="./sa-credentials.json" --ciphertext-file="./sa-credentials.json.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION


sudo rm *.enc
sudo rm -f /tmp/collected-keys.zip
