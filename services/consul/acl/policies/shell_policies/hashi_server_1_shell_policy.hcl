
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

key_prefix "traefik-service-routes/" {
   policy = "write"
}

key_prefix "traefik-dashboards-ip-allowlist/" {
   policy = "write"
}

key_prefix "" {
   policy = "read"
}

event "traefik-routes-updated" {
  policy = "write"
}

session_prefix "project_lock_session__" {
  policy = "write"
}

session_prefix "" {
  policy = "read"
}