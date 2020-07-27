# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies via API & UI
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "secret/data/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

# delete or destroy secret-versions
path "secret/delete/*" {
  capabilities = ["update"]
}
path "secret/destroy/*" {
  capabilities = ["update"]
}


# list, view or delete metadata for secret-versions
path "secret/metadata/*" {
  capabilities = ["list", "read", "delete"]
}