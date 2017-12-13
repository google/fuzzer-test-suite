#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Creates a dispatcher VM in GCP and sends it all the files and configurations
# it needs to begin an experiment.

. "$(dirname "$0")/../common.sh"
. "${SCRIPT_DIR}/common-harness.sh"

set -eu

if [[ -z ${1+x} || -z ${2+x} || -z ${3+x} ]]; then
  echo "Usage: $0 benchmark1[,benchmark2,...] experiment-config fuzz-config1 [fuzz-config2 ...]"
  exit 1
fi

# Set up experiment configuration directory for dispatcher to use.
readonly CONFIG_DIR="config"
rm -rf "${CONFIG_DIR}"
mkdir "${CONFIG_DIR}"
cp "$2" "${CONFIG_DIR}/parameters.cfg"
. "${CONFIG_DIR}/parameters.cfg"

# Write bmarks to file for dispatcher to read.
echo "BMARKS=$1" > "${CONFIG_DIR}/bmarks.cfg"

# Copy fuzzing configs to single directory for sending to dispatcher.
readonly FENGINE_CONFIG_DIR="fengine-configs"
declare -ar FENGINE_CONFIGS=( "${@:3}" )
rm -rf "${FENGINE_CONFIG_DIR}"
mkdir "${FENGINE_CONFIG_DIR}"
for fengine_config in "${FENGINE_CONFIGS[@]}"; do
  cp "${fengine_config}" "${FENGINE_CONFIG_DIR}/"
done

# Create or reuse service account auth key.
if [[ ! -e "./autogen-PRIVATE-key.json" ]]; then
  gcloud iam service-accounts keys create autogen-PRIVATE-key.json \
    --iam-account="${SERVICE_ACCOUNT}" --key-file-type=json
fi
cp autogen-PRIVATE-key.json "${CONFIG_DIR}/"

# Create dispatcher in the background.
readonly INSTANCE_NAME="dispatcher-${EXPERIMENT}"
create_or_start "${INSTANCE_NAME}" &

gsutil -m rsync -rd "${FENGINE_CONFIG_DIR}" \
  "${GSUTIL_BUCKET}/${EXPERIMENT}/input/fengine-configs"

# Send the entire local FTS repository to the dispatcher.
# Local changes to any file will propagate.
gsutil -m rsync -rd -x ".git/*" "$(dirname "${SCRIPT_DIR}")" \
  "${GSUTIL_BUCKET}/${EXPERIMENT}/input/FTS"

# Send other configs.
gsutil -m rsync -rd "${CONFIG_DIR}" \
  "${GSUTIL_BUCKET}/${EXPERIMENT}/input/FTS/engine-comparison/config"

# Configure dispatcher and run startup script.
wait
robust_begin_gcloud_ssh "${INSTANCE_NAME}"
gcloud compute scp "${SCRIPT_DIR}/startup-dispatcher.sh" \
  "${INSTANCE_NAME}:~/" --zone us-west1-b
cmd="chmod 750 ~/startup-dispatcher.sh"
cmd="${cmd} && docker run --rm -d -e INSTANCE_NAME=${INSTANCE_NAME}"
cmd="${cmd}   -e EXPERIMENT=${EXPERIMENT} --cap-add SYS_PTRACE"
cmd="${cmd}   --name=dispatcher-container gcr.io/fuzzer-test-suite/dispatcher"
cmd="${cmd}   tail -f /dev/null"
cmd="${cmd} && docker cp startup-dispatcher.sh dispatcher-container:/work/"
cmd="${cmd} && docker exec dispatcher-container /work/startup-dispatcher.sh"
gcloud compute ssh "${INSTANCE_NAME}" --command="${cmd}"
