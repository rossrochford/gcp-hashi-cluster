#!/bin/bash

INSTANCE_INDEX=$1

export PYTHONPATH=/scripts/utilities


if [[ $INSTANCE_INDEX == "0" ]]; then

  consul kv put traefik/config/main-node-hostname $(hostname)
  consul kv put traefik/config/dashboards-ip-allowlist '["0.0.0.0/0"]'

  # create /etc/traefik/traefik-consul-service.json and register service, note: it will have no upstreams yet
  python3 /scripts/utilities/py_utilities/render_config_templates.py "traefik"
  consul services register /etc/traefik/traefik-consul-service.json
fi


cp /scripts/services/traefik/conf/traefik.toml /etc/traefik/traefik.toml
consul-template -template "/scripts/services/traefik/conf/dynamic-conf.toml.tmpl:/etc/traefik/dynamic-conf.toml" -once


if [[ $INSTANCE_INDEX == "0" ]]; then

  consul-template -once -template '/scripts/services/traefik/conf/traefik.nomad.tmpl:/etc/traefik/traefik.nomad'
  nomad job run /etc/traefik/traefik.nomad
  sleep 4
  consul intention create -allow traefik '*'

fi

/scripts/services/traefik/init/launch_sidecar_proxy.sh
/scripts/services/traefik/init/launch_config_watcher.sh
