#!/bin/bash

export ANSIBLE_REMOTE_USER=$USER

ansible-playbook -i ./auth.gcp.yml "playbooks/nomad/pull-docker-images.yml" \
  --extra-vars="ansible_ssh_private_key_file=/etc/collected-keys/sa-ssh-key"
