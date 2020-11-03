#!/bin/bash

PROJECT_INFO=$(metadata_get project_info)
REGION=$(metadata_get region)
KMS_KEY=$(metadata_get kms_encryption_key)
KMS_KEYRING=$(metadata_get kms_encryption_key_ring)

sudo mkdir -p /etc/collected-keys

sudo unzip /tmp/collected-keys.zip -d /etc/collected-keys

cd /etc/collected-keys


sudo gcloud kms decrypt --plaintext-file="./sa-ssh-key.pub" --ciphertext-file="./sa-ssh-key.pub.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
sudo chmod 644 sa-ssh-key.pub

sudo gcloud kms decrypt --plaintext-file="./sa-ssh-key" --ciphertext-file="./sa-ssh-key.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
sudo chmod 644 sa-ssh-key

sudo gcloud kms decrypt --plaintext-file="./sa-credentials.json" --ciphertext-file="./sa-credentials.json.enc" --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
sudo chmod 644 sa-credentials.json


sudo rm *.enc
sudo rm -f /tmp/collected-keys.zip
