#!/bin/bash

VPC_HOST_PROJECT_ID=$1
CLUSTER_PROJECT_ID=$2


CLUSTER_PROJECT_DESCRIPTION=$(gcloud compute project-info describe --project $CLUSTER_PROJECT_ID --format=json)

SECURITY_POLICIES_QUOTA=$(echo $CLUSTER_PROJECT_DESCRIPTION | jq  '.quotas[] | select( .metric == "SECURITY_POLICIES" ) | .limit')
SECURITY_POLICIES_USAGE=$(echo $CLUSTER_PROJECT_DESCRIPTION | jq  '.quotas[] | select( .metric == "SECURITY_POLICIES" ) | .usage')

SP_REMAINDER=$(($SECURITY_POLICIES_QUOTA-$SECURITY_POLICIES_USAGE))


if [[ $SP_REMAINDER == 0 ]]; then
  echo "not enough quota for: SECURITY_POLICIES, you need a quota of at least: 1"
fi


# todo:
# "URL_MAPS" (1)
# SECURITY_POLICY_RULES (5)
# SECURITY_POLICY_CEVAL_RULES (5)
# IN_USE_ADDRESSES (1)
# BACKEND_SERVICES (1)
# STATIC_ADDRESSES (1)