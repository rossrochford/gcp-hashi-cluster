#!/bin/bash


# install go-discover  (todo: do this in base image)
sudo apt install -y golang-go
sudo go get -u github.com/hashicorp/go-discover/cmd/discover
# note: path might be different when building with packer
sudo mv  /root/go/bin/discover /usr/local/bin/discover
