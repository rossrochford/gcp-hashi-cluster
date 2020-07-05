#!/bin/bash

# when cluster initialization is complete, some sensitive data needs to be removed


# this file should exist if we're running it on hashi-server-1 and cleanup.sh hasn't previously been run
export CONSUL_BOOTSTRAP_TOKEN=$(cat /tmp/ansible-data/consul-bootstrap-token.json | jq -r ".SecretID")

export ANSIBLE_REMOTE_USER=$USER


ansible-playbook -i ./auth.gcp.yml "playbooks/remove-initialization-data.yml" \
  --extra-vars="ansible_ssh_private_key_file=/etc/collected-keys/sa-ssh-key"


# should we also remove /etc/collected-keys/ on hashi-server-1?
