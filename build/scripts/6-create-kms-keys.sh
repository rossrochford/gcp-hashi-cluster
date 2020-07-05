#!/bin/bash

# SA for cluster
SERVICE_ACCOUNT_EMAIL=$1
CLUSTER_PROJECT_ID=$2
REGION=$3

KMS_KEYRING=$4
KMS_KEY=$5


echo "creating keyring for Vault"
gcloud kms keyrings create $KMS_KEYRING  --location $REGION --project $CLUSTER_PROJECT_ID
gcloud kms keyrings add-iam-policy-binding $KMS_KEYRING --location=$REGION --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" --role=roles/owner --project $CLUSTER_PROJECT_ID


echo "granting service account IAM permissions for the key ring"
gcloud kms keyrings add-iam-policy-binding $KMS_KEYRING --location=$REGION --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" --role=roles/cloudkms.admin --project $CLUSTER_PROJECT_ID
gcloud kms keyrings add-iam-policy-binding $KMS_KEYRING --location=$REGION --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" --role=roles/cloudkms.cryptoKeyEncrypterDecrypter --project $CLUSTER_PROJECT_ID
gcloud kms keyrings add-iam-policy-binding $KMS_KEYRING --location=$REGION --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" --role=roles/cloudkms.signerVerifier --project $CLUSTER_PROJECT_ID


echo "creating encryption key for Vault"
gcloud kms keys create $KMS_KEY --location=$REGION --keyring=$KMS_KEYRING --purpose=encryption --project $CLUSTER_PROJECT_ID
gcloud kms keys update $KMS_KEY --location=$REGION --keyring=$KMS_KEYRING --rotation-period=30d --next-rotation-time=$(date -d "+30 days" --iso-8601) --project $CLUSTER_PROJECT_ID
