#!/bin/bash

sudo useradd --system --home /etc/vault.d --shell /bin/false vault

mkdir -p /etc/vault.d/
chmod -R 0777 /etc/vault.d/

sudo chown --recursive vault:vault /etc/vault.d

mkdir -p /opt/vault/logs/
sudo chown --recursive vault:vault /opt/vault


curl -s -L -o ~/vault.zip https://releases.hashicorp.com/vault/1.4.2/vault_1.4.2_linux_amd64.zip

sudo unzip ~/vault.zip

rm ~/vault.zip

# note: a different way of installing it is shown here: https://learn.hashicorp.com/vault/day-one/ops-deployment-guide#step-2-install-vault
sudo install -c -m 0755 vault /usr/bin


# todo: this has some additional steps:
#  https://learn.hashicorp.com/vault/day-one/ops-deployment-guide#step-2-install-vault
