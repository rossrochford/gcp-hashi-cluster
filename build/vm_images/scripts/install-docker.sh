#!/bin/bash

sudo groupadd docker
sudo usermod -aG docker ubuntu

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update -y
sudo apt install -y docker-ce
sudo mkdir -p /root/.docker/
sudo systemctl enable docker
sudo systemctl start docker
