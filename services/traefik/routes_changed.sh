#!/bin/bash

# note: this gets run prematurely on Traefik nodes when the Consul agent starts up due to
# a known issue with Consul watches, the commands below should still work even with missing KV data


/scripts/services/traefik/render_traefik_sidecar_config.sh

/scripts/services/traefik/render_traefik_routes_config.sh

consul services register /etc/traefik/traefik-consul-service.json

# does sidecar proxy need restarting? or a SIGHUP?