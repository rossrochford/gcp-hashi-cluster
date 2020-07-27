agent "{{ node_name }}" {
  policy = "read"
}

node_prefix "" {
   policy = "read"
}

service_prefix "" {
   policy = "read"
}

key_prefix "" {
   policy = "read"
}

key_prefix "hashi-cluster-nodes/" {
  policy = "deny"
}

key_prefix "{{ ctn_prefix }}/" {
  policy = "read"
}

session_prefix "" {
  policy = "read"
}

event_prefix "" {
  policy = "read"
}
