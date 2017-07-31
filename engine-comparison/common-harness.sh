#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Every "gcloud compute ssh/scp/etc" needs --zone, otherwise throws warning
GCLOUD_ZONE="us-west1-b"

# Almost definitely fine to be in the public domain
SERVICE_ACCOUNT="373628893752-compute@developer.gserviceaccount.com"

# Sometimes, gcloud compute instances create returns before a VM is ready to be
# SSH'ed into. Use this function after "instances create" to prevent skipped calls
robust_begin_gcloud_ssh () {
  INSTANCE_NAME=$1
  while :
  do
    ! (gcloud compute ssh $INSTANCE_NAME --command="echo ping"\
      --zone=$GCLOUD_ZONE 2>&1 | grep "ERROR") && break
    echo "GCloud VM isn't ready yet. Rerunning SSH momentarily."
    sleep 5 # arbitrary choice of time
  done
}

create_or_start() {
  INSTANCE_NAME=$1
  if gcloud compute instances describe $INSTANCE_NAME --zone=$GCLOUD_ZONE 2>&1 | grep "ERROR"; then
    gcloud_create $INSTANCE_NAME
  else
    gcloud compute instances start $INSTANCE_NAME --zone=$GCLOUD_ZONE
  fi

}
gcloud_create() {
  INSTANCE_NAME=$1
  IMAGE_FAMILY="docker-ubuntu" # may want flexiblity i.e. ${2:-docker-ubuntu}
  gcloud compute instances create $INSTANCE_NAME --image-family=$IMAGE_FAMILY\
    --zone=$GCLOUD_ZONE --service-account=$SERVICE_ACCOUNT --scopes=compute-rw,storage-rw,default
}

gcloud_delete() {
  INSTANCE_NAME=$1
  gcloud compute instances delete $INSTANCE_NAME --zone=$GCLOUD_ZONE
}
