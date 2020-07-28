#!/bin/bash

# Generate initial bootstrap token for Consul with global-management policy, store this and its SecretID somewhere safe.

mkdir -p /tmp/ansible-data
consul acl bootstrap -format=json > /tmp/ansible-data/consul-bootstrap-token.json

if [[ $? != 0 ]]; then
  echo "error: 'consul acl bootstrap' failed"; exit 1
fi

export BOOTSTRAP_TOKEN=$(cat /tmp/ansible-data/consul-bootstrap-token.json | jq -r ".SecretID")
export CONSUL_HTTP_TOKEN=$BOOTSTRAP_TOKEN


cd /scripts/services/consul/


# create a read-write policy/token for the Consul web UI
consul acl policy create -name consul-ui-policy-rw -rules @acl/policies/operator_ui_read-write.hcl
consul acl role create -name=consul-ui-role-rw -policy-name=consul-ui-policy-rw
consul acl token create -role-name consul-ui-role-rw -format=json > /tmp/ansible-data/consul-ui-token-rw.json


# create a read-only policy/token for the Consul web UI
consul acl policy create -name consul-ui-policy-ro -rules @acl/policies/operator_ui_read-only.hcl
consul acl role create -name=consul-ui-role-ro -policy-name=consul-ui-policy-ro
consul acl token create -role-name consul-ui-role-ro -format=json > /tmp/ansible-data/consul-ui-token-ro.json


consul acl policy create -name read-only-policy -rules @acl/policies/shell_policies/read_only_policy.hcl
consul acl role create -name=read-only-role -policy-name=read-only-policy
# note: tokens are created in set_agent_token_for_shell.sh


# used for token in /etc/environment on hashi-server-1:
consul acl policy create -name hashi-server-1-shell-policy -rules @acl/policies/shell_policies/hashi_server_1_shell_policy.hcl
consul acl role create -name=hashi-server-1-shell-role -policy-name=hashi-server-1-shell-policy


# used for token in /etc/environment on traefik nodes:
consul acl policy create -name traefik-shell-policy -rules @acl/policies/shell_policies/traefik_shell_policy.hcl
consul acl role create -name=traefik-shell-role -policy-name=traefik-shell-policy


consul acl policy create -name nomad-server-policy -rules @acl/policies/nomad_server_policy.hcl
consul acl role create -name=nomad-server-role -policy-name=nomad-server-policy
# note: tokens are created in services/nomad/init/setup_nomad_server.sh


consul acl policy create -name nomad-client-policy -rules @acl/policies/nomad_client_policy.hcl
consul acl role create -name=nomad-client-role -policy-name=nomad-client-policy
# note: tokens are created in services/nomad/init/setup_nomad_client.sh


consul acl policy create -name vault-policy -rules @acl/policies/vault_policy.hcl
consul acl role create -name=vault-role -policy-name=vault-policy
# (vault agent tokens get created on vault nodes)



# todo - continue reading: https://learn.hashicorp.com/consul/security-networking/production-acls
