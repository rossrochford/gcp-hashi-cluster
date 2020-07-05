#!/bin/bash


mkdir -p /etc/consul.d/tls-certs-new
cd /etc/consul.d/tls-certs-new


# create the CA
consul tls ca create


SERVER_IP_ADDRESSES=$(go_discover consul-server)


# create a certificate for each server
for IP in $SERVER_IP_ADDRESSES
do
  # todo: what happens if an external ip is assigned to hashi-server-1? we need to ensure the private ip is used here (consistent with ansible)
  consul tls cert create -server -additional-ipaddress=$IP
  mv dc1-server-consul-0-key.pem "dc1-server-consul-$IP-key.pem"
  mv dc1-server-consul-0.pem "dc1-server-consul-$IP.pem"
done


# create a certificate for the client agents (unlike the servers, the same one can be used by all clients)
CLIENT_IP_ADDRESSES=$(go_discover consul-client)
IP_ARGS=$(echo " $CLIENT_IP_ADDRESSES" | sed -e 's| | --additional-ipaddress=|g')

consul tls cert create -client $IP_ARGS
