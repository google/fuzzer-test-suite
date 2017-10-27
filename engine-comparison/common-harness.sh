#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Defines utility functions and variables used by the engine-comparison tool.

# Define zone to avoid prompt
declare -xr CLOUDSDK_COMPUTE_ZONE="us-west1-b"
declare -xr GSUTIL_BUCKET="gs://fuzzer-test-suite"

# Almost definitely fine to be in the public domain
declare -xr SERVICE_ACCOUNT="373628893752-compute@developer.gserviceaccount.com"

# It takes some time for sshd to start up after a VM is created.  This function
# repeatedly tries to connect until the ssh succeeds.
robust_begin_gcloud_ssh() {
  local instance_name=$1
  while true; do
    gcloud compute ssh "${instance_name}" --command="echo ping" 2>&1 \
      | grep "ERROR" || break
    echo "GCloud VM isn't ready yet. Rerunning SSH momentarily."
    sleep 5
  done
}

create_or_start() {
  local instance_name=$1
  local metadata=$2
  local metadata_from_file=$3
  gcloud compute instances describe "${instance_name}" 2>&1 | grep "ERROR"
  if [[ $? == 0 ]]; then
    echo "${instance_name} doesn't exist yet. Now creating VM."
    gcloud_create "${instance_name}" "${metadata}" "${metadata_from_file}"
  else
    gcloud compute instances start "${instance_name}"
  fi
}

gcloud_create() {
  local instance_name=$1
  [[ -n $2 ]] && local metadata_cmd="--metadata $2"
  [[ -n $3 ]] && local metadata_ff_cmd="--metadata-from-file $3"

  # The dispatcher should be more powerful
  if echo "${instance_name}" | grep "dispatcher"; then
    gcloud compute instances create "${instance_name}" \
      --image-family="docker-ubuntu" --service-account="${SERVICE_ACCOUNT}" \
      --machine-type="n1-standard-16" --scopes="compute-rw,storage-rw,default" \
      --boot-disk-size=100GB ${metadata_cmd} ${metadata_ff_cmd}
  else
    gcloud compute instances create "${instance_name}" \
      --image-family="docker-ubuntu" --service-account="${SERVICE_ACCOUNT}" \
      --machine-type="n1-standard-2" --scopes="compute-rw,storage-rw,default" \
      ${metadata_cmd} ${metadata_ff_cmd} --network=runner-net --no-address
  fi
}

gcloud_delete() {
  local instance_name=$1
  gcloud compute instances delete "${instance_name}"
}
