#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Creates a dispatcher VM in GCP and sends it all the files and configurations
# it needs to begin an experiment.

. "$(dirname "$0")/../common.sh"
. "${SCRIPT_DIR}/common-harness.sh"

set -eux

if [[ -z $1 || -z $2 ]]; then
  echo "Usage: $0 benchmark1[,benchmark2,...] fuzz-config1 [fuzz-config2 ...]"
  exit 1
fi

# Write bmarks to file for dispatcher to read.
readonly CONFIG_DIR="${SCRIPT_DIR}/config"
. "${CONFIG_DIR}/parameters.cfg"
echo "BMARKS=$1" > "${CONFIG_DIR}/bmarks.cfg"

# Copy fuzzing configs to single directory for sending to dispatcher.
readonly FENGINE_CONFIG_DIR="${CONFIG_DIR}/fengine-configs"
declare -ar FENGINE_CONFIGS=( "${@:2}" )
rm -rf "${FENGINE_CONFIG_DIR}"
mkdir "${FENGINE_CONFIG_DIR}"
for fengine_config in "${FENGINE_CONFIGS[@]}"; do
  cp "${fengine_config}" "${FENGINE_CONFIG_DIR}/"
done

# Pass service account auth key
if [[ ! -e "${CONFIG_DIR}/autogen-PRIVATE-key.json" ]]; then
  gcloud iam service-accounts keys create \
    "${CONFIG_DIR}/autogen-PRIVATE-key.json" \
    --iam-account="${SERVICE_ACCOUNT}" --key-file-type=json
fi

# -m parallelizes operation; -r sets recursion, -d syncs deletion of files
gsutil -m rsync -rd "${FENGINE_CONFIG_DIR}" \
  "${GSUTIL_BUCKET}/${EXPERIMENT}/input/fengine-configs"
rm -rf "${FENGINE_CONFIG_DIR}"

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gsutil -m rsync -rd -x ".git/*" "$(dirname "${SCRIPT_DIR}")" \
  "${GSUTIL_BUCKET}/${EXPERIMENT}/input/FTS"

#gsutil -m acl ch -r -u ${SERVICE_ACCOUNT}:O ${GSUTIL_BUCKET}

# Set up dispatcher and run its startup script.
readonly INSTANCE_NAME="dispatcher-${EXPERIMENT}"
create_or_start "${INSTANCE_NAME}"
robust_begin_gcloud_ssh "${INSTANCE_NAME}"
cmd="mkdir -p ~/input"
cmd="${cmd} && gsutil -m rsync -rd ${GSUTIL_BUCKET}/${EXPERIMENT}/input ~/input"
cmd="${cmd} && bash ~/input/FTS/engine-comparison/startup-dispatcher.sh"
gcloud compute ssh "${INSTANCE_NAME}" --command="${cmd}"
