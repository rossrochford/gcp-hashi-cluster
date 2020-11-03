
# The anonymous token is implicitly used if no token is supplied. Once the cluster is operational, you should
# limit these permissions (this tutorial just grants node_prefix "" { policy = "read" } & service "consul" { policy = "read" } : https://learn.hashicorp.com/consul/day-0/acl-guide)

# another option is to set acl.tokens.default (e.g. if different node/agents need different access) and restrict the anonymous token even further

key_prefix "" {
  policy = "write"
}

agent_prefix "" {
  policy = "write"
}

event_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "write"
}

query_prefix "" {
  policy = "write"
}

service_prefix "" {
  policy = "write"
}

session_prefix "" {
  policy = "write"
}