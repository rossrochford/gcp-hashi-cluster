#!/bin/bash

INSTANCE_NAME=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
INSTANCE_ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d'/' -f4)

set_startup_status() {
  gcloud compute instances update $INSTANCE_NAME --update-labels "startup_status=$1" --zone=$INSTANCE_ZONE
}


set_startup_status "initializing"



# pull repo and place it in /scripts directory
cd /
git clone https://github.com/rossrochford/gcp-hashi-cluster.git
mv /gcp-hashi-cluster /scripts
cd /scripts
# git checkout dev


/scripts/infrastructure/cluster-nodes/scripts/_initialize_instance.sh


if [[ $? == 0 ]]; then
  set_startup_status "complete"
else
  set_startup_status "failed"
fi
