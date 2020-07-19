#!/bin/bash

cd /scripts

cp services/consul/conf/consul-fluentd.conf /etc/google-fluentd/config.d/consul.conf
cp services/nomad/conf/nomad-fluentd.conf /etc/google-fluentd/config.d/nomad.conf
cp services/traefik/conf/traefik-fluentd.conf /etc/google-fluentd/config.d/traefik.conf
cp services/system-misc/fluentd/syslog-fluentd.conf /etc/google-fluentd/config.d/syslog.conf

service google-fluentd start