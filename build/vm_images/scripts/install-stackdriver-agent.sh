#!/bin/bash

# add stackdriver-agent package for 'monitoring agent' (stackdriver)
curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh
sudo bash add-monitoring-agent-repo.sh
sudo apt-get update -y

apt-get install -y 'stackdriver-agent=6.*'

mkdir -p /opt/stackdriver/collectd/etc/collectd.d/

service stackdriver-agent start
