
agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "write"
}

# what about key_prefix?


# note: this effectively allows unrestricted access to the datacenter because it can generate tokens with any resource and policy.
# A more restrictive approach is to only grant this to operators (https://learn.hashicorp.com/consul/security-networking/managing-acl-policies#secure-access-control-operator-only-access)
# which I think would mean that an operator needs to do some manual steps before a new service can be deployed?
acl = "write"
