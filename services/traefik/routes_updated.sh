#!/bin/bash

MAIN_TRAEFIK_HOSTNAME=$(consul kv get traefik/config/main-node-hostname)
THIS_HOSTNAME=$(hostname)

if [[ "$THIS_HOSTNAME" == "$MAIN_TRAEFIK_HOSTNAME" ]]; then
  python3 /scripts/utilities/py_utilities/consul_kv.py expand-traefik-service-routes
else
  sleep 3
fi

python3 /scripts/utilities/py_utilities/render_config_templates.py "traefik"

# upstreams may have changed so re-register service, is this necessary?
consul services register /etc/traefik/traefik-consul-service.json

consul-template -template "/scripts/services/traefik/conf/dynamic-conf.toml.tmpl:/etc/traefik/dynamic-conf.toml" -once


# does sidecar proxy need restarting? or a SIGHUP?