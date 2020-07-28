#!/bin/bash

PROJECT_INFO=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info)
NUM_HASHI_SERVERS=$(echo $PROJECT_INFO | jq -r ".num_hashi_servers")

mkdir -p /tmp/ansible-data


vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/ansible-data/vault-init-keys.json

ROOT_TOKEN=$(cat /tmp/ansible-data/vault-init-keys.json | jq -r ".root_token")
export VAULT_TOKEN="$ROOT_TOKEN"

vault login $ROOT_TOKEN

vault secrets enable -path=secret kv-v2

vault auth enable gcp



vault policy write nomad-server /scripts/services/vault/policies/nomad-server-policy.hcl

# tokens generated for Nomad tasks will be allowed this policy (see "allowed_policies" in nomad-cluster-role.json)
vault policy write nomad-client-base /scripts/services/vault/policies/nomad-client-base-policy.hcl


# Create the token role with Vault. This manages which Vault policies are accessible by Nomad jobs.
# This role is also referenced in Nomad config at base.hcl.tmpl:vault.create_from_role (see: https://www.nomadproject.io/docs/configuration/vault/#create_from_role and https://www.nomadproject.io/docs/vault-integration/#retrieving-the-token-role-based-token)
vault write /auth/token/roles/nomad-cluster @/scripts/services/vault/roles/nomad-cluster-role.json
# Warning: never add "nomad-server" to allowed_policies, otherwise Nomad tasks will be able to generate new tokens with any policy.


# create tokens and gather them into a json string
TOKENS=""
for ((n=0; n < $NUM_HASHI_SERVERS; n++)); do
  TK=$(vault token create -policy nomad-server -period 72h -orphan -field=token)
  TOKENS="$TOKENS $TK"
done

TOKENS_JSON=$(python3 -c '
import json
import sys
tokens = [a for a in sys.argv[1:] if a.strip()]
print(json.dumps({"nomad_vault_tokens": tokens}))
' $TOKENS)


# echo tokens for ansible to capture
echo $ROOT_TOKEN
echo $TOKENS_JSON
