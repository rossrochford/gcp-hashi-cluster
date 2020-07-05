
# Policy for operator UI that can add new intentions and update the KV store.
# For a read-only policy use operator_ui_read-only.hcl instead.

service_prefix "" {
  policy = "read"
  intentions = "write"
}

key_prefix "" {
  policy = "write"
}

node_prefix "" {
  policy = "read"
}

acl = "read"
