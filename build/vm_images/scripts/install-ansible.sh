#!/bin/bash

sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
pip3 install ansible==2.10.1 --user
