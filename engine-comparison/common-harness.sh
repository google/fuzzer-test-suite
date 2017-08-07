#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Define zone to avoid prompt
GCLOUD_ZONE="us-west1-b"
export CLOUDSDK_COMPUTE_ZONE=$GCLOUD_ZONE

# Almost definitely fine to be in the public domain
SERVICE_ACCOUNT="373628893752-compute@developer.gserviceaccount.com"

GSUTIL_BUCKET="gs://fuzzer-test-suite"

# Sometimes, gcloud compute instances create returns before a VM is ready to be
# SSH'ed into. Use this function after "instances create" to prevent skipped calls
robust_begin_gcloud_ssh () {
  INSTANCE_NAME=$1
  while :
  do
    ! (gcloud compute ssh $INSTANCE_NAME --command="echo ping"\
      2>&1 | grep "ERROR") && break
    echo "GCloud VM isn't ready yet. Rerunning SSH momentarily."
    sleep 5 # arbitrary choice of time
  done
}

create_or_start() {
  INSTANCE_NAME=$1
  STARTUP_SCRIPT=$2

  if gcloud compute instances describe $INSTANCE_NAME 2>&1 | grep "ERROR"; then
    echo "$INSTANCE_NAME doesn't exist yet. Now creating VM."
    gcloud_create $INSTANCE_NAME $STARTUP_SCRIPT
  else
    gcloud compute instances start $INSTANCE_NAME
  fi

}
gcloud_create() {
  INSTANCE_NAME=$1
  
  # If there is a second argument
  if [[ -n $2 ]]; then
    STARTUP_SCRIPT_CMD="--metadata-from-file startup-script=$2"
  fi
  
  # The dispatcher should be more powerful
  MACHINE_TYPE=n1-standard-1
  echo $INSTANCE_NAME | grep dispatcher && MACHINE_TYPE=n1-standard-4

  IMAGE_FAMILY="docker-ubuntu"
  gcloud compute instances create $INSTANCE_NAME --image-family=$IMAGE_FAMILY \
    --service-account=$SERVICE_ACCOUNT --machine-type=$MACHINE_TYPE \
    --scopes=compute-rw,storage-rw,default $STARTUP_SCRIPT_CMD
}

gcloud_delete() {
  INSTANCE_NAME=$1
  gcloud compute instances delete $INSTANCE_NAME
}
