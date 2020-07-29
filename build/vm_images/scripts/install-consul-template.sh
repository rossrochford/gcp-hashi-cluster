#!/bin/bash

# install consul-template
curl -O https://releases.hashicorp.com/consul-template/0.25.1/consul-template_0.25.1_linux_amd64.tgz
tar -zxf consul-template_0.25.1_linux_amd64.tgz
mv consul-template /usr/local/bin/consul-template
rm consul-template_0.25.1_linux_amd64.tgz