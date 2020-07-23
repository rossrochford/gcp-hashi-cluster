#!/bin/bash

mkdir -p /tmp/ansible-data/

NODE_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')

export ANSIBLE_REMOTE_USER=$USER

export CONSUL_HTTP_ADDR="http://$NODE_IP:8500"


export CONSUL_BOOTSTRAP_TOKEN=$1
export GOSSIP_ENCRYPTION_KEY=$2
NEW_INSTANCE_NAMES=$3

export CONSUL_HTTP_TOKEN=$CONSUL_BOOTSTRAP_TOKEN

run_playbook () {
  # assumed to run from dir: /scripts/operations/ansible
  ansible-playbook -i ./auth.gcp.yml "playbooks/init_new_clients/$1/$2" \
    --extra-vars="ansible_ssh_private_key_file=/etc/collected-keys/sa-ssh-key"

  if [[ $? != 0 ]]; then
    log_write "critical" "playbook $1/$2 failed, exiting initialize_new_hashi_clients.sh"
    exit 1
  fi

}

if [[ -z $NEW_INSTANCE_NAMES ]]; then
  echo "NEW_INSTANCE_NAMES argument not provided"; exit 1
fi


python3 /scripts/utilities/py_utilities/render_config_templates.py "ansible" $NEW_INSTANCE_NAMES

if [[ $(check_exists "file" "/scripts/operations/ansible/auth.gcp.yml") == "no" ]]; then
  ln -s /scripts/build/ansible/auth.gcp.yml /scripts/operations/ansible/auth.gcp.yml
fi

if [[ $(check_exists "file" "/scripts/operations/ansible/ansible.cfg") == "no" ]]; then
  ln -s /scripts/build/ansible/ansible.cfg /scripts/operations/ansible/ansible.cfg
fi


# create and place TLS certs
# ----------------------------
/scripts/services/consul/init/create_tls_certs-new_clients.sh $NEW_INSTANCE_NAMES

run_playbook consul place-tls-certs.yml

rm -f /etc/consul.d/dc1-client-consul-0.pem
rm -f /etc/consul.d/dc1-client-consul-0-key.pem



run_playbook consul set-client-agent-tokens.yml


run_playbook consul start-client-agents.yml

sleep 15
run_playbook consul register-nodes-with-consul-kv.yml


run_playbook nomad initialize-nomad.yml


run_playbook consul set-agent-tokens-for-shell.yml


# re-render ansible auth.ccp.yml without 'new_hashi_clients' group
python3 /scripts/utilities/py_utilities/render_config_templates.py "ansible"
