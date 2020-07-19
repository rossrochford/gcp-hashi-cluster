#!/bin/bash


AGENT_TOKEN=$(cat /tmp/ansible-data/traefik-shell-token.json | jq -r ".SecretID")

cp /scripts/services/traefik/systemd/watch-traefik-routes-updated.service /etc/systemd/system/watch-traefik-routes-updated.service

sed -i "s|CONSUL_HTTP_TOKEN=none|CONSUL_HTTP_TOKEN=$AGENT_TOKEN|g" /etc/systemd/system/watch-traefik-routes-updated.service

chmod 0644 /etc/systemd/system/watch-traefik-routes-updated.service
systemctl daemon-reload

systemctl enable watch-traefik-routes-updated.service
systemctl start watch-traefik-routes-updated.service
