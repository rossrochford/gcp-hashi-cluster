#!/bin/bash


# render consul config files
python3 /scripts/utilities/py_utilities/render_config_templates.py "consul"


# setup Consul config and services
# cp services/consul/conf/agent/* /etc/consul.d/

chown --recursive consul:consul /etc/consul.d
chmod 640 /etc/consul.d/*.hcl

#cp services/consul/systemd/consul-server.service /etc/systemd/system/consul-server.service
#cp services/consul/systemd/consul-client.service /etc/systemd/system/consul-client.service

sudo systemctl daemon-reload
