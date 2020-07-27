
# required for watch/events
# todo: restrict this to: agent "{{ node_name }} { }, haven't tested it but it should work
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
   policy = "read"
}

service_prefix "" {
   policy = "read"
}

key_prefix "{{ ctp_prefix }}/metadata" {
  policy = "write"
}

key_prefix "{{ ctp_prefix }}/metadata-lock" {
  policy = "write"
}

key_prefix "hashi-cluster-nodes/" {
  policy = "deny"
}

key_prefix "{{ ctn_prefix }}/" {
  policy = "write"
}

key_prefix "" {
   policy = "read"
}

event_prefix "" {
  policy = "read"
}

session_prefix "project_lock_session__" {
  policy = "write"
}

session_prefix "" {
  policy = "read"
}



# traefik stuff

key_prefix "traefik-service-routes/" {
  policy = "write"
}

key_prefix "traefik-sidecar-upstreams/" {
  policy = "write"
}

key_prefix "traefik-dashboards-ip-allowlist/" {
  policy = "write"
}

service_prefix "traefik" {
   policy = "write"
}

event "traefik-routes-updated" {
  policy = "write"
}
