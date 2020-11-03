#!/bin/bash

KEY=$1

PROJECT_INFO=$(cat /scripts/build/conf/project-info.json)

if [[ $KEY == "node_name" ]]; then
  echo $NODE_NAME
elif [[ $KEY == "node_type" ]]; then
  echo $NODE_TYPE
elif [[ $KEY == "node_ip" ]]; then
  echo $NODE_IP
elif [[ $KEY == "project_info" ]]; then
  echo $PROJECT_INFO
elif [[ $KEY == "cluster_service_project_id" ]]; then
  CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")
  echo $CLUSTER_PROJECT_ID
elif [[ $KEY == "kms_encryption_key" ]]; then
  KMS_KEY=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key")
  echo "$KMS_KEY"
elif [[ $KEY == "kms_encryption_key_ring" ]]; then
  KMS_KEYRING=$(echo $PROJECT_INFO | jq -r ".kms_encryption_key_ring")
  echo "$KMS_KEYRING"
elif [[ $KEY == "num_hashi_servers" ]]; then
  NUM_HASHI_SERVERS=$(echo "$PROJECT_INFO" | jq -r ".num_hashi_servers")
  echo "$NUM_HASHI_SERVERS"
elif [[ $KEY == "container_registry_hostname" ]]; then
  CONTAINER_REGISTRY_HOSTNAME=$(echo "$PROJECT_INFO" | jq -r ".container_registry_hostname")
  echo "$CONTAINER_REGISTRY_HOSTNAME"
fi
