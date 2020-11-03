#!/bin/bash

pip3 install --force-reinstall ansible ansible-base

sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

sudo ansible-galaxy collection install community.general
