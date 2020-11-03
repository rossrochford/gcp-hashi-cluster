#!/bin/bash


mv /tmp/scripts /scripts

# copy utility scripts
cp /scripts/utilities/kv/ctn /usr/local/bin/ctn
cp /scripts/utilities/kv/ctp /usr/local/bin/ctp
cp /scripts/utilities/check_exists /usr/local/bin/check_exists
cp /scripts/utilities/go_discover /usr/local/bin/go_discover
cp /scripts/utilities/log_write /usr/local/bin/log_write
cp /scripts/utilities/metadata_get /usr/local/bin/metadata_get


export HOSTING_ENV=vagrant
CLUSTER_PROJECT_ID=$(metadata_get cluster_service_project_id)
export CTN_PREFIX="hashi-cluster-nodes/$NODE_NAME"
export CTP_PREFIX="hashi-cluster-projects/$CLUSTER_PROJECT_ID"
export PYTHONPATH=/scripts/utilities


# todo: do the same in cluster-nodes/startup_scripts/_initialize_instance.sh
{
  echo "NODE_IP=\"$NODE_IP\""
  echo "NODE_NAME=\"$NODE_NAME\""
  echo "NODE_TYPE=\"$NODE_TYPE\""
  echo "CLUSTER_PROJECT_ID=\"$CLUSTER_PROJECT_ID\""
  echo "CTN_PREFIX=\"$CTN_PREFIX\""
  echo "CTP_PREFIX=\"$CTP_PREFIX\""
  echo "PYTHONPATH=$PYTHONPATH"
  echo "HOSTING_ENV=$HOSTING_ENV"
} >> /etc/environment


#echo "NODE_IP=\"$NODE_IP\"" >> /etc/environment
#echo "NODE_NAME=\"$NODE_NAME\"" >> /etc/environment
#echo "NODE_TYPE=\"$NODE_TYPE\"" >> /etc/environment
#echo "GCP_INSTANCE_ID=\"$GCP_INSTANCE_ID\"" >> /etc/environment
#echo "CLUSTER_PROJECT_ID=\"$CLUSTER_PROJECT_ID\"" >> /etc/environment
#echo "CTN_PREFIX=\"$CTN_PREFIX\"" >> /etc/environment
#echo "CTP_PREFIX=\"$CTP_PREFIX\"" >> /etc/environment
#echo "PYTHONPATH=/scripts/utilities" >> /etc/environment


cd /scripts


python3 utilities/py_utilities/create_metadata.py

python3 utilities/py_utilities/render_config_templates.py "ansible"
rm /scripts/build/ansible/ansible.cfg  # todo: use similar rename pattern in GCP and rename this file to ansible-gcp.cfg
mv /scripts/build/ansible/ansible-vagrant.cfg /etc/ansible/ansible.cfg


# setup Consul config and services
services/consul/init/vm_init.sh


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
