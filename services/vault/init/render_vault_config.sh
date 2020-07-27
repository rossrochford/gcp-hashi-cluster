#!/bin/bash

STATE=$1


NODE_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')

if [[ $STATE == "initial" ]]; then

    consul kv put "$CTN_PREFIX/vault-config/api-addr" "http://$NODE_IP:8200"
    consul kv put "$CTN_PREFIX/vault-config/cluster-addr" "http://$NODE_IP:8201"

    consul kv put "$CTN_PREFIX/vault-config/tls-disable" "true"
    consul kv put "$CTN_PREFIX/vault-config/ca-cert" "none"
    consul kv put "$CTN_PREFIX/vault-config/tls-cert-file" ""
    consul kv put "$CTN_PREFIX/vault-config/tls-key-file" ""

elif [[ $STATE == "tls-certs-ready" ]]; then

    consul kv put "$CTN_PREFIX/vault-config/api-addr" "https://$NODE_IP:8200"
    consul kv put "$CTN_PREFIX/vault-config/cluster-addr" "https://$NODE_IP:8201"

    consul kv put "$CTN_PREFIX/vault-config/tls-disable" "false"
    consul kv put "$CTN_PREFIX/vault-config/ca-cert" "/etc/vault.d/certs/vault_rootCA.pem"
    consul kv put "$CTN_PREFIX/vault-config/tls-cert-file" "/etc/vault.d/certs/certificate.pem"
    consul kv put "$CTN_PREFIX/vault-config/tls-key-file" "/etc/vault.d/certs/key.pem"

else
    echo "render_vault_config.sh got unexpected state: $STATE"
    exit 1
fi

sleep 1

consul-template -template "/scripts/services/vault/systemd/vault.service.tmpl:/etc/systemd/system/vault.service" -once
consul-template -template "/scripts/services/vault/conf/vault_config.hcl.tmpl:/etc/vault.d/vault_config.hcl" -once


chmod 640 /etc/vault.d/vault_config.hcl
sudo chown vault:vault /etc/vault.d/vault_config.hcl

#chmod 0664 /etc/systemd/system/vault.service
chmod 0644 /etc/systemd/system/vault.service

sudo systemctl daemon-reload
