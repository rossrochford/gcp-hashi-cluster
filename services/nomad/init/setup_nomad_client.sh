#!/bin/bash

VAULT_HOST=$1

NODE_TYPE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/node-type)


consul acl token create -role-name nomad-client-role -format=json > /tmp/ansible-data/nomad-client-consul-token.json
TOKEN=$(cat /tmp/ansible-data/nomad-client-consul-token.json | jq -r ".SecretID")


consul kv put "$CTN_PREFIX/nomad-config/consul-token" $TOKEN
consul kv put "$CTN_PREFIX/nomad-config/consul-ca-file" "/etc/consul.d/tls-certs/consul-agent-ca.pem"
consul kv put "$CTN_PREFIX/nomad-config/consul-cert-file" "/etc/consul.d/tls-certs/dc1-client-consul.pem"
consul kv put "$CTN_PREFIX/nomad-config/consul-key-file" "/etc/consul.d/tls-certs/dc1-client-consul-key.pem"

consul kv put "$CTN_PREFIX/nomad-config/vault-host" $VAULT_HOST


cd /scripts/services/nomad

consul-template -template "conf/agent/base.hcl.tmpl:/etc/nomad.d/base.hcl" -once
consul-template -template "conf/agent/client.hcl.tmpl:/etc/nomad.d/client.hcl" -once
consul-template -template "systemd/nomad-client.service.tmpl:/etc/systemd/system/nomad-client.service" -once


chmod -R 700 /etc/nomad.d/
chmod 0644 /etc/systemd/system/nomad-client.service

systemctl daemon-reload