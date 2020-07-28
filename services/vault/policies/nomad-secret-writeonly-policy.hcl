
# ability to add or update secrets but not read their contents
path "secret/data/*"
{
  capabilities = ["create", "update"]
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