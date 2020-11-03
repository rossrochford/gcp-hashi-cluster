#!/bin/bash

mkdir -p /etc/consul.d
useradd --system --home /etc/consul.d --shell /bin/false consul

wget https://releases.hashicorp.com/consul/1.8.5/consul_1.8.5_linux_amd64.zip

unzip consul_1.8.5_linux_amd64.zip -d .
chown root:root consul
mv consul /usr/local/bin/consul
rm consul_1.8.5_linux_amd64.zip

mkdir -p /opt/consul/logs/
chown --recursive consul:consul /opt/consul

docker pull envoyproxy/envoy:v1.11.2@sha256:a7769160c9c1a55bb8d07a3b71ce5d64f72b1f665f10d81aa1581bc3cf850d09
docker pull envoyproxy/envoy:v1.14.2
docker pull envoyproxy/envoy:v1.14.4

# install CNI plugins
curl -L -o cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v0.8.7/cni-plugins-linux-amd64-v0.8.7.tgz
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf cni-plugins.tgz
echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables