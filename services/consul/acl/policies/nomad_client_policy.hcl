
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

# todo: consider narrowing this on "traefik" and "vault" nodes (meaning, we'd need to create a separate policy for those nodes)
service_prefix "" {
  policy = "write"
}

# set to read if using Consul KV with Consul Template in Nomad
key_prefix "" {
  policy = "deny"
}
