#!/bin/bash

# based on: https://learn.hashicorp.com/consul/day-0/acl-guide#configure-the-anonymous-token-optional


consul acl policy create -name anonymous-policy -rules @/scripts/services/consul/acl/policies/anonymous_token_policy.hcl

consul acl token update -id 00000000-0000-0000-0000-000000000002 -policy-name=anonymous-policy