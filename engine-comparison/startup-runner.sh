#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on creation of each runner VM.
# Pulls down the benchmark fuzzer built for this runner, configures the runner
# container, and runs the runner script.

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance"
METADATA_URL="${METADATA_URL}/attributes"
readonly METADATA_URL
readonly BENCHMARK="$(curl "${METADATA_URL}/benchmark" -H \
  "Metadata-Flavor: Google")"
readonly FENGINE_NAME="$(curl "${METADATA_URL}/fengine" -H \
  "Metadata-Flavor: Google")"
readonly FOLDER_NAME="${BENCHMARK}-with-${FENGINE_NAME}"

mkdir -p ~/input
gsutil -m rsync -rd "gs://fuzzer-test-suite/binary-folders/${FOLDER_NAME}" \
  ~/input
sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps
find ~/input -name "*.sh" -exec chmod 750 {} \;
sudo docker build -t base-image ~/input
sudo docker run -e INSTANCE_NAME="${HOSTNAME}" --cap-add SYS_PTRACE base-image \
  /work/runner.sh
