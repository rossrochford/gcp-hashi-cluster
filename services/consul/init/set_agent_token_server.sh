#!/bin/bash

BOOTSTRAP_TOKEN=$1
NODE_TYPE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/node-type)
NODE_NAME=$(hostname)   # or could use metadata API

mkdir -p /tmp/ansible-data

cd /scripts/services/consul/

AGENT_POLICY_NAME="consul-agent-policy-$NODE_NAME"
AGENT_ROLE_NAME="consul-agent-role-$NODE_NAME"

export CONSUL_HTTP_TOKEN=$BOOTSTRAP_TOKEN

consul acl policy create -name $AGENT_POLICY_NAME -rules @acl/policies/consul_agent_policy.hcl
consul acl role create -name=$AGENT_ROLE_NAME -policy-name=$AGENT_POLICY_NAME


consul acl token create -role-name $AGENT_ROLE_NAME -format=json -token=$BOOTSTRAP_TOKEN > /tmp/ansible-data/consul-agent-token.json
AGENT_TOKEN=$(cat /tmp/ansible-data/consul-agent-token.json | jq -r ".SecretID")

if [[ -z $AGENT_TOKEN ]]; then
  echo "error: consul AGENT_TOKEN was not created"; exit 1
fi

# note: because enable_token_persistence = true, you don't need to re-apply this after restarting the agent
consul acl set-agent-token agent $AGENT_TOKEN


# cleanup
rm /tmp/ansible-data/consul-agent-token.json