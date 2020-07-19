#!/bin/bash

RESOURCES=$(/scripts/utilities/get_node_resources.sh)

CPU_MHZ=$(echo $RESOURCES | cut -d' ' -f1)
MEMORY=$(echo $RESOURCES | cut -d' ' -f2)

# subtract 200 Mb to allow some slack
((MEMORY=MEMORY-200))


# These resource limits will be set in Nomad's agent config on Traefik nodes and in the 'traefik.nomad' job file. This tells Nomad
# that Traefik nodes, which are also Nomad clients, are 100% utilized so that no other services are ever allocated to these nodes.
# The networking and sidecar proxies are configured with the assumption that this will always be true.
# Note: for the sake of simplicity, these are project-wide values, it is assumed that all Traefik nodes in the cluster are the same size.
consul kv put "$CTP_PREFIX/nomad-config/traefik/cpu-total-compute" $CPU_MHZ
consul kv put "$CTP_PREFIX/nomad-config/traefik/memory-total-mb" $MEMORY
