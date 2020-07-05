#!/bin/bash


# create /etc/traefik/traefik-service.json with jinja2
python3 /scripts/utilities/py_utilities/render_config_templates.py "traefik"


if [[ $(check_exists "file" "/etc/traefik/traefik-consul-service-token.json") == "no" ]]; then
  consul acl token create -description="Traefik service token" -service-identity="traefik" -format=json > /etc/traefik/traefik-consul-service-token.json
fi


# only needs rendering once per node, the only template variables are node-ip and the token, it doesn't need re-rendering when Traefik routes are updated
if [[ $(check_exists "file" "/etc/systemd/system/traefik-sidecar-proxy.service") == "no" ]]; then

  TOKEN=$(cat /etc/traefik/traefik-consul-service-token.json | jq -r ".SecretID")

  consul-template -template "/scripts/services/traefik/systemd/traefik-sidecar-proxy.service.tmpl:/etc/systemd/system/traefik-sidecar-proxy.service" -once
  sed -i "s|CONSUL_HTTP_TOKEN=none|CONSUL_HTTP_TOKEN=$TOKEN|g" /etc/systemd/system/traefik-sidecar-proxy.service

  chmod 0644 /etc/systemd/system/traefik-sidecar-proxy.service
  systemctl daemon-reload
fi

