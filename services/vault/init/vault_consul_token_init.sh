#!/bin/bash

BOOTSTRAP_TOKEN=$1


consul acl token create -role-name vault-role -format=json -token=$BOOTSTRAP_TOKEN > /tmp/ansible-data/vault-token.json

TOKEN=$(cat /tmp/ansible-data/vault-token.json | jq -r ".SecretID")


consul kv put "$CTN_PREFIX/vault-config/consul-http-token" $TOKEN
# sed -i "s/CONSUL_HTTP_TOKEN=none/CONSUL_HTTP_TOKEN=$TOKEN/g" /etc/systemd/system/vault.service
