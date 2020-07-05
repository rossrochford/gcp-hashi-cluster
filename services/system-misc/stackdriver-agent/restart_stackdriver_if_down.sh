#!/bin/bash

PORT_EXISTS=$(netstat -tulpn | grep ":8125 ")

if [[ ! "$PORT_EXISTS" ]]
  then
    echo "Port 8125 not open, restarting stackdriver-agent"
    service stackdriver-agent restart
fi
