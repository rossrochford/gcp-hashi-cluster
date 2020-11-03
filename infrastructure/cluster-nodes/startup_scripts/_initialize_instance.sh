#!/bin/bash

cd /scripts


NODE_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
NODE_NAME=$(hostname)
NODE_TYPE=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/node-type)
GCP_INSTANCE_ID=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id)
PROJECT_INFO=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info)
CLUSTER_PROJECT_ID=$(echo $PROJECT_INFO | jq -r ".cluster_service_project_id")


service ntp reload


# project-wide and node-wide prefixes for storing metadata in Consul
# "CTN: 'consul-template-node-prefix'  CTP: 'consul-template-project-prefix'
export CTN_PREFIX="hashi-cluster-nodes/$NODE_NAME"
export CTP_PREFIX="hashi-cluster-projects/$CLUSTER_PROJECT_ID"
echo "CTN_PREFIX=\"$CTN_PREFIX\"" >> /etc/environment
echo "CTP_PREFIX=\"$CTP_PREFIX\"" >> /etc/environment
echo "HOSTING_ENV=gcp" >> /etc/environment


echo "PYTHONPATH=/scripts/utilities" >> /etc/environment
echo "GCP_INSTANCE_ID=$GCP_INSTANCE_ID" >> /etc/environment


echo "creating metadata"
export PYTHONPATH=/scripts/utilities
python3 utilities/py_utilities/create_metadata.py


# render ansible config and create symlinks
python3 utilities/py_utilities/render_config_templates.py "ansible"
ln -s /scripts/build/ansible/ansible.cfg /scripts/operations/ansible/ansible.cfg
ln -s /scripts/build/ansible/auth.gcp.yml /scripts/operations/ansible/auth.gcp.yml


# copy utility scripts
cp /scripts/utilities/kv/ctn /usr/local/bin/ctn
cp /scripts/utilities/kv/ctp /usr/local/bin/ctp
cp /scripts/utilities/check_exists /usr/local/bin/check_exists
cp /scripts/utilities/go_discover /usr/local/bin/go_discover
cp /scripts/utilities/log_write /usr/local/bin/log_write
cp /scripts/utilities/metadata_get /usr/local/bin/metadata_get


# setup Consul config and services
services/consul/init/vm_init.sh


# setup stackdriver-agent and fluentd
services/system-misc/stackdriver-agent/vm_init.sh
services/system-misc/fluentd/vm_init.sh


mkdir -p /tmp/ansible-data/
chmod 0777 /tmp/ansible-data/


if [[ "$NODE_TYPE" == "vault" ]]
  then
    echo "CONSUL_HTTP_ADDR=\"127.0.0.1:8500\"" >> /etc/environment
    cp services/vault/init/vault_env.sh /etc/profile.d/vault_env.sh
else
  # these need to be set for the Consul and Nomad CLIs to work in ssh sessions
  echo "CONSUL_HTTP_ADDR=\"$NODE_IP:8500\"" >> /etc/environment
  echo "NOMAD_ADDR=\"http://$NODE_IP:4646\"" >> /etc/environment
fi
