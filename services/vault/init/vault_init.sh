#!/bin/bash

NUM_HASHI_SERVERS=$(metadata_get num_hashi_servers)

vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/ansible-data/vault-init-keys.json

ROOT_TOKEN=$(cat /tmp/ansible-data/vault-init-keys.json | jq -r ".root_token")
export VAULT_TOKEN="$ROOT_TOKEN"


UNSEAL_KEY="none"

if [[ $HOSTING_ENV == "vagrant" ]]; then
  UNSEAL_KEY=$(cat /tmp/ansible-data/vault-init-keys.json | jq -r .unseal_keys_b64[0])
  vault operator unseal $UNSEAL_KEY
fi

vault login "$ROOT_TOKEN"

vault secrets enable -path=secret kv-v2

if [[ $HOSTING_ENV == "gcp" ]]; then
  vault auth enable gcp
fi


# allows Nomad to generate tokens for tasks
vault policy write nomad-server /scripts/services/vault/policies/nomad-server-policy.hcl

# allows Nomad tasks to read secrets at /secret/data/nomad/*   (to add more capabilities see "allowed_policies" in nomad-cluster-role.json)
vault policy write nomad-client-base /scripts/services/vault/policies/nomad-client-base-policy.hcl
vault write /auth/token/roles/nomad-cluster @/scripts/services/vault/roles/nomad-cluster-role.json  # referenced in server.hcl:create_from_role
# Warning: never add "nomad-server" to allowed_policies, otherwise Nomad tasks will be able to generate new tokens with any policy.


# allows a developer to write/update (but not read) secrets at: /secret/data/nomad/*
vault policy write nomad-secret-writer /scripts/services/vault/policies/nomad-secret-writeonly-policy.hcl
WRITEONLY_TOKEN=$(vault token create -policy nomad-secret-writer -period 72h -orphan -field=token)


# create nomad-server tokens and gather them into a json string
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
echo $WRITEONLY_TOKEN
echo $TOKENS_JSON
echo $UNSEAL_KEY
