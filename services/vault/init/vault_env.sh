#!/bin/bash


alias v="vault"
alias vault="vault"
export VAULT_ADDR="http://127.0.0.1:8200"

# don't store vault commands in shell history
export HISTIGNORE="&:vault*"
