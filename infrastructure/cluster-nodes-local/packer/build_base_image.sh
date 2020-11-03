#!/bin/bash

VARS_FILEPATH="/home/ross/code/gcp-hashi-cluster/build/conf/project-info.json"

if [ ! -f "./ubuntu2004.box" ]; then
    wget https://app.vagrantup.com/generic/boxes/ubuntu2004/versions/3.0.36/providers/virtualbox.box -o ./ubuntu2004.box
fi


rm -rf /home/ross/code/gcp-hashi-cluster/infrastructure/cluster-nodes-local/packer/base_image

packer build -force -var-file=$VARS_FILEPATH hashi_base.pkr.hcl


# to clear vagrant cache run:
# rm -rf ~/.vagrant.d/boxes/*
# rm -rf ~/VirtualBox\ VMs/*