#!/bin/bash


vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/vault-init-keys.json

ROOT_TOKEN=$(cat /tmp/vault-init-keys.json | jq -r ".root_token")

vault login $ROOT_TOKEN

vault secrets enable -path=kv kv

vault auth enable gcp



# vault policy write nomad-cluster /scripts/services/vault/policies/nomad-cluster-policy.hcl
# vault write auth/gcp/role/nomad-cluster type="gce" policies="nomad-cluster" bound_projects="<my-project>"



# taken from vault_nomad_role_init.sh
# ---------------------------
vault policy write nomad-server /scripts/services/vault/policies/nomad-server-policy.hcl

# Create the token role with Vault. This manages which Vault policies are accessible by Nomad jobs.
# This role is also referenced in Nomad config at base.hcl.tmpl:vault.create_from_role (see: https://www.nomadproject.io/docs/configuration/vault/#create_from_role and https://www.nomadproject.io/docs/vault-integration/#retrieving-the-token-role-based-token)
vault write /auth/token/roles/nomad-cluster @/scripts/services/vault/roles/nomad-cluster-role.json
# We've set disallowed_policies to "nomad-server" to prevent tokens created by Nomad from generating new tokens
# with different policies.


# create tokens for nomad-server agents, echo them for ansible to capture
export VAULT_TOKEN="$ROOT_TOKEN"
export PYTHONPATH=/scripts/utilities
TOKENS_JSON=$(python3 /scripts/services/vault/init/create_nomad_vault_tokens.py)

echo $ROOT_TOKEN
echo $TOKENS_JSON
