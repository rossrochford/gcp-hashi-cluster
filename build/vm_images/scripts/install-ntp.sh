#!/bin/bash


apt install -y ntp

cp /home/packer/services/system-misc/ntp/ntp.conf /etc/ntp.conf

service ntp reload