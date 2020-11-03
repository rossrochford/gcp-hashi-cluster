#!/bin/bash

BOOTSTRAP_TOKEN=$1

NODE_TYPE=$(metadata_get "node_type")
NODE_NAME=$(metadata_get "node_name")


if [[ $NODE_NAME == "hashi-server-1" ]]; then
  # hashi-server-1 shell token needs some additional abilities because our operations scripts use it (e.g. updating traefik-service-routes in KV)
  consul acl token create -role-name hashi-server-1-shell-role -format=json -token=$BOOTSTRAP_TOKEN  > /tmp/ansible-data/hashi-server-1-shell-token.json
  AGENT_TOKEN=$(cat /tmp/ansible-data/hashi-server-1-shell-token.json | jq -r ".SecretID")
  echo "CONSUL_HTTP_TOKEN=$AGENT_TOKEN" >> /etc/environment
  exit 0
fi


if [[ $NODE_TYPE == "traefik" ]]; then
  # traefik nodes need to be able to register its service and update traefik-service-routes in KV
  consul acl token create -role-name traefik-shell-role -format=json -token=$BOOTSTRAP_TOKEN  > /tmp/ansible-data/traefik-shell-token.json
  AGENT_TOKEN=$(cat /tmp/ansible-data/traefik-shell-token.json | jq -r ".SecretID")
  echo "CONSUL_HTTP_TOKEN=$AGENT_TOKEN" >> /etc/environment
  exit 0
fi




consul acl token create -role-name read-only-role -format=json -token=$BOOTSTRAP_TOKEN  > /tmp/ansible-data/read-only-token.json
RO_AGENT_TOKEN=$(cat /tmp/ansible-data/read-only-token.json | jq -r ".SecretID")

echo "CONSUL_HTTP_TOKEN=$RO_AGENT_TOKEN" >> /etc/environment
