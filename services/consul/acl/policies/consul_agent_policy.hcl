
node "{{ node_name }}" {
  policy = "write"
}

# note: some tutorials include this, some do not. The cluster seems to function with or without it.
node_prefix "" {
   policy = "read"
}

# todo: consider limiting the scope of this on "traefik" and "vault" nodes (see: (2))
service_prefix "" {
  policy = "read"
}

agent "" {
  policy = "write"
}

key_prefix "{{ ctp_prefix }}/" {
  policy = "write"
}

key_prefix "{{ ctn_prefix }}/" {
  policy = "write"
}

# is this necessary for watches to work?
event_prefix "" {
  policy = "read"
}



# traefik stuff

{% if node_type == "traefik" %}
key_prefix "traefik-service-routes/" {
  policy = "write"
}

key_prefix "traefik-sidecar-upstreams/" {
  policy = "write"
}

key_prefix "traefik-dashboards-ip-allowlist/" {
  policy = "write"
}

# "traefik-routes-updated" event causes this service to be re-registered in routes_changed.sh
service_prefix "traefik" {
   policy = "write"
}
{% endif %}




/*
Suggestion from: https://learn.hashicorp.com/consul/day-0/acl-guide


1) It is recommended that each client get an ACL agent token with only node write
privileges for its own node name, and service read privileges for the service
prefixes expected to be registered on that client.

2) Anti-entropy syncing requires the ACL agent token to have service:write privileges
for all services that may be registered with the agent. You should provide
service:write for each separate service via a separate token that is used when
registering via the API, or provided along with the registration in the configuration
file. Note that service:write is the privilege required to assume the identity of a
service and so Consul Connect's intentions are only enforceable to the extent that
each service instance is unable to gain service:write on any other service name.
For more details consult the Connect security documentation.

*/
