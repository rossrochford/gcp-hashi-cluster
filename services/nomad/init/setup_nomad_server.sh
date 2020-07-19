#!/bin/bash

CONSUL_BOOTSTRAP_TOKEN=$1
VAULT_HOST=$2
NOMAD_VAULT_TOKEN=$3

mkdir -p /tmp/ansible-data

export CONSUL_HTTP_TOKEN=$CONSUL_BOOTSTRAP_TOKEN


consul acl token create -role-name nomad-server-role -format=json -token=$CONSUL_BOOTSTRAP_TOKEN > /tmp/ansible-data/nomad-server-consul-token.json
TOKEN=$(cat /tmp/ansible-data/nomad-server-consul-token.json | jq -r ".SecretID")


consul kv put "$CTN_PREFIX/nomad-config/consul-token" $TOKEN
consul kv put "$CTN_PREFIX/nomad-config/consul-ca-file" "/etc/consul.d/tls-certs/consul-agent-ca.pem"
consul kv put "$CTN_PREFIX/nomad-config/consul-cert-file" "/etc/consul.d/tls-certs/dc1-server-consul.pem"
consul kv put "$CTN_PREFIX/nomad-config/consul-key-file" "/etc/consul.d/tls-certs/dc1-server-consul-key.pem"

consul kv put "$CTN_PREFIX/nomad-config/vault-host" $VAULT_HOST
consul kv put "$CTN_PREFIX/nomad-config/vault-token" $NOMAD_VAULT_TOKEN


cd /scripts/services/nomad

consul-template -template "conf/agent/base.hcl.tmpl:/etc/nomad.d/base.hcl" -once
consul-template -template "conf/agent/server.hcl.tmpl:/etc/nomad.d/server.hcl" -once
consul-template -template "systemd/nomad-server.service.tmpl:/etc/systemd/system/nomad-server.service" -once


chmod -R 700 /etc/nomad.d/
chmod 0644 /etc/systemd/system/nomad-server.service

systemctl daemon-reload
