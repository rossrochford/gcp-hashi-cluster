#!/bin/bash


GOSSIP_KEY=$1

sed -i "s|__GOSSIP_ENCRYPTION_KEY__|$GOSSIP_KEY|g" /etc/consul.d/base.hcl

