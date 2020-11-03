
# with V2 API secrets are placed under secret/data instead of secret/
path "secret/data/nomad/*"
{
  capabilities = ["read"]
}
