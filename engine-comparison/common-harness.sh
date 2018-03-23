#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Defines utility functions and variables used by the engine-comparison tool.

# Returns 0 if we are running on a GCP instance, else 1.
on_gcp_instance() {
  curl -i metadata.google.internal 2>/dev/null | grep "Metadata-Flavor: Google"
}

# It takes some time for sshd to start up after a VM is created.  This function
# repeatedly tries to connect until the ssh succeeds.
robust_begin_gcloud_ssh() {
  local instance_name=$1
  local zone=$2
  local tries=0
  while [[ ${tries} -lt 10 ]]; do
    if on_gcp_instance; then
      gcloud beta compute ssh "${instance_name}" --command="echo ping" \
        --zone="${zone}" --internal-ip 2>&1 | grep "ERROR" >/dev/null || break
    else
      gcloud compute ssh "${instance_name}" --command="echo ping" \
        --zone="${zone}" 2>&1 | grep "ERROR" > /dev/null || break
    fi
    echo "GCP instance isn't ready yet. Rerunning SSH momentarily."
    sleep 5
    tries=$((tries + 1))
  done
  if [[ ${tries} -ge 10 ]]; then
    echo "Error: Couldn't SSH to instance"
    exit 1
  fi
}

create_or_start() {
  local instance_name=$1
  local service_account=$2
  local zone=$3
  local metadata=""
  [[ -n ${4+x} ]] && metadata=$4
  local metadata_from_file=""
  [[ -n ${5+x} ]] && metadata_from_file=$5

  if gcloud compute instances describe "${instance_name}" --zone="${zone}" \
    2>&1 | grep "ERROR" > /dev/null; then
    echo "${instance_name} doesn't exist yet. Now creating VM."
    gcloud_create "${instance_name}" "${service_account}" "${zone}" \
      "${metadata}" "${metadata_from_file}"
  else
    gcloud compute instances start "${instance_name}" --zone="${zone}"
  fi
}

gcloud_create() {
  local instance_name=$1
  local service_account=$2
  local zone=$3
  local metadata_cmd=""
  [[ -n $4 ]] && metadata_cmd="--metadata $4"
  local metadata_ff_cmd=""
  [[ -n $5 ]] && metadata_ff_cmd="--metadata-from-file $5"

  # The dispatcher should be more powerful
  if echo "${instance_name}" | grep "dispatcher" > /dev/null; then
    gcloud compute instances create "${instance_name}" \
      --image-family="cos-stable" --image-project="cos-cloud" \
      --machine-type="n1-standard-16" --scopes="compute-rw,storage-rw,default" \
      --boot-disk-type="pd-ssd" --boot-disk-size="500GB" \
      --service-account="${service_account}" --zone="${zone}" \
      ${metadata_cmd} ${metadata_ff_cmd}
  else
    gcloud compute instances create "${instance_name}" \
      --image-family="cos-stable"  --image-project="cos-cloud" \
      --network=runner-net --no-address \
      --machine-type="n1-standard-2" --scopes="compute-rw,storage-rw,default" \
      --service-account="${service_account}" --zone="${zone}" \
      ${metadata_cmd} ${metadata_ff_cmd}
  fi
}

gcloud_delete() {
  local instance_name=$1
  gcloud compute instances delete -q "${instance_name}"
}
