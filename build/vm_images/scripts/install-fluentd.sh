#!/bin/bash

mkdir -p /etc/google/auth/

# add fluentd package for 'logging agent'
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
sudo bash add-logging-agent-repo.sh
sudo apt-get update -y

apt-get install -y 'google-fluentd=1.*'
apt-get install -y google-fluentd-catch-all-config-structured

mkdir -p /etc/google-fluentd/config.d/
service google-fluentd start
