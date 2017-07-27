#!/bin/bash

. $(dirname $0)/../common.sh

# Create provided gcloud vm instance
gcloud_create() {
  INSTANCE_NAME=$1
  IMAGE_FAMILY="docker-ubuntu" # may want flexiblity i.e. ${2:-docker-ubuntu}
  gcloud compute instances create $INSTANCE_NAME --image-family=$IMAGE_FAMILY --zone=$GCLOUD_ZONE
}

# Delete provided gcloud vm instance
gcloud_delete() {
  INSTANCE_NAME=$1
  gcloud compute instances delete $INSTANCE_NAME --zone=$GCLOUD_ZONE
}

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}" # may want flexibility i.e. ${2:-"dispatcher-${DD}-${MM}"}

COMMAND=$1
[[ $COMMAND != "create" ]] && [[ $COMMAND != "delete" ]] && echo "USAGE: First argument must be 'create' or 'delete' " && exit 1

gcloud_${COMMAND} $INSTANCE_NAME
