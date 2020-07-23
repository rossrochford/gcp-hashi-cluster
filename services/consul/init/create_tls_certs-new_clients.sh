#!/bin/bash

CLIENT_IP_ADDRESSES=$1  # comma-separated list

cd /etc/consul.d/tls-certs


# create a certificate for the client agents (unlike the servers, the same one can be used by clients)
IP_ARGS=$(echo " $CLIENT_IP_ADDRESSES" | sed -e 's|,| --additional-ipaddress=|g')
consul tls cert create -client $IP_ARGS
