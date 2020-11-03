#!/bin/bash

# temp
export HASHI_REPO_DIRECTORY=/home/ross/code/gcp-hashi-cluster

if [[ -z $HASHI_REPO_DIRECTORY ]]; then
  echo "error: HASHI_REPO_DIRECTORY env variable must be set"; exit 1
fi

if [ ! -f "$HASHI_REPO_DIRECTORY/infrastructure/cluster-nodes-local/packer/base_image/package.box" ]; then
  ./packer/build_base_image.sh
fi


# for vagrant, assuming only 1 vault server at 172.20.20.13  (todo: fetch this from vagrant-cluster.json)
export HOSTING_ENV=vagrant
$HASHI_REPO_DIRECTORY/build/scripts/tls-certs/create_vault_tls_certs.sh 172.20.20.13


vagrant destroy -f

vagrant up

rm -rf /tmp/ansible-data/vault-tls-certs.zip

vagrant ssh hashi-server-1 -c "cd /scripts/build/ansible; ./initialize_cluster.sh"