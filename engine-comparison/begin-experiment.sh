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

# Validate experiment configuration
if [[ -z ${EXPERIMENT+x} || -z ${RUNNERS+x} || -z ${JOBS+x} || \
  -z ${MAX_RUNS+x} || -z ${MAX_TOTAL_TIME+x} || \
  -z ${CLOUDSDK_COMPUTE_ZONE+x} || -z ${GSUTIL_BUCKET+x} || \
  -z ${GSUTIL_WEB_BUCKET+x} || -z ${SERVICE_ACCOUNT+x} ]]; then
  echo "Error: experiment-config must define the following parameters:"
  echo "  EXPERIMENT, RUNNERS, JOBS, MAX_RUNS, MAX_TOTAL_TIME,"
  echo "  CLOUDSDK_COMPUTE_ZONE, GSUTIL_BUCKET, GSUTIL_WEB_BUCKET,"
  echo "  and SERVICE_ACCOUNT"
  exit 1
fi
if ! echo "${EXPERIMENT}" | grep "^[a-z0-9-][a-z0-9-]*$" &> /dev/null; then
  echo "Error: EXPERIMENT must match [a-z0-9-]+"
  exit 1
fi
for numeric_param in ${RUNNERS} ${JOBS} ${MAX_RUNS} ${MAX_TOTAL_TIME}; do
  numeric_regex="^-?[0-9]+$"
  if [[ ! "${numeric_param}" =~ ${numeric_regex} ]]; then
    echo "Error: RUNNERS, JOBS, MAX_RUNS, and MAX_TOTAL_TIME must be integers"
    exit 1
  fi
done
for bucket_param in ${GSUTIL_BUCKET} ${GSUTIL_WEB_BUCKET}; do
  bucket_regex="^gs://"
  if [[ ! "${bucket_param}" =~ ${bucket_regex} ]]; then
    echo "Error: GSUTIL_BUCKET and GSUTIL_WEB_BUCKET must start with gs://"
    exit 1
  fi
done

# Validate benchmark names
readonly NUM_BAD_NAMES="$(comm -23 \
  <(echo "$1" | tr "," "\n" | sort -u) \
  <((ls "${SCRIPT_DIR}/.."; echo all; echo most; echo small) | sort -u) \
  | wc -l)"
if [[ "${NUM_BAD_NAMES}" -ne 0 ]]; then
  echo "Error: ${NUM_BAD_NAMES} benchmark names are invalid"
  exit 1
fi

# Write bmarks to file for dispatcher to read.
echo "BMARKS=$1" > "${CONFIG_DIR}/bmarks.cfg"

# Copy fuzzing configs to single directory for sending to dispatcher.
readonly FENGINE_CONFIG_DIR="fengine-configs"
declare -ar FENGINE_CONFIGS=( "${@:3}" )
rm -rf "${FENGINE_CONFIG_DIR}"
mkdir "${FENGINE_CONFIG_DIR}"
readonly RESERVED_LENGTH="$( \
  find "${SCRIPT_DIR}/.." -maxdepth 1 -mindepth 1 -printf "%f\n" \
  | awk '{ print length }' \
  | sort -rn \
  | head -n1)"
readonly MAX_EXP_FENGINE_LENGTH=$((59 - RESERVED_LENGTH))
for fengine_config in "${FENGINE_CONFIGS[@]}"; do
  fengine_name="$(basename "${fengine_config}")"
  # Validate fengine_config name
  if ! echo "${fengine_name}" | grep "^[a-z0-9-][a-z0-9-]*$" &> /dev/null
  then
    echo "Error: fuzz-configs must match [a-z0-9-]+"
    exit 1
  fi
  # Ensure runner VM names won't be too long.
  exp_fengine_length="$(echo "${EXPERIMENT}${fengine_name}" | wc -c)"
  if [[ ${exp_fengine_length} -gt ${MAX_EXP_FENGINE_LENGTH} ]]; then
    echo "Error: len(${EXPERIMENT}) + len(${fengine_name}) = ${exp_fengine_length}"
    echo "       Sum must be less than ${MAX_EXP_FENGINE_LENGTH} due to VM naming restrictions"
    exit 1
  fi
  cp "${fengine_config}" "${FENGINE_CONFIG_DIR}/"
done

gcloud config set project "${PROJECT}"

# Create or reuse service account auth key.
if [[ ! -e "./autogen-PRIVATE-key.json" ]]; then
  gcloud iam service-accounts keys create autogen-PRIVATE-key.json \
    --iam-account="${SERVICE_ACCOUNT}" --key-file-type=json
fi
cp autogen-PRIVATE-key.json "${CONFIG_DIR}/"

# Create dispatcher in the background.
readonly INSTANCE_NAME="dispatcher-${EXPERIMENT}"
create_or_start "${INSTANCE_NAME}" "${SERVICE_ACCOUNT}" \
  "${CLOUDSDK_COMPUTE_ZONE}" &

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
robust_begin_gcloud_ssh "${INSTANCE_NAME}" "${CLOUDSDK_COMPUTE_ZONE}"
cmd="docker run --rm -e INSTANCE_NAME=${INSTANCE_NAME}"
cmd="${cmd} -e EXPERIMENT=${EXPERIMENT} -e GSUTIL_BUCKET=${GSUTIL_BUCKET}"
cmd="${cmd} --cap-add=SYS_PTRACE --cap-add=SYS_NICE"
cmd="${cmd} --name=dispatcher-container gcr.io/fuzzer-test-suite/dispatcher"
cmd="${cmd} /work/startup-dispatcher.sh"
if on_gcp_instance; then
  gcloud beta compute ssh "${INSTANCE_NAME}" --command="${cmd}" --internal-ip \
    --zone="${CLOUDSDK_COMPUTE_ZONE}"
else
  gcloud compute ssh "${INSTANCE_NAME}" --command="${cmd}" \
    --zone="${CLOUDSDK_COMPUTE_ZONE}"
fi
