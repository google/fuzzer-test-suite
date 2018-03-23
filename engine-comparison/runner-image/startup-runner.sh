#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on creation of each runner VM.
# Configures the runner container, and runs the runner script.

METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance"
METADATA_URL="${METADATA_URL}/attributes"
readonly METADATA_URL
readonly BENCHMARK="$(curl "${METADATA_URL}/benchmark" -H \
  "Metadata-Flavor: Google")"
readonly FENGINE_NAME="$(curl "${METADATA_URL}/fengine" -H \
  "Metadata-Flavor: Google")"
readonly EXPERIMENT="$(curl "${METADATA_URL}/experiment" -H \
  "Metadata-Flavor: Google")"
readonly BUCKET="$(curl "${METADATA_URL}/bucket" -H \
  "Metadata-Flavor: Google")"
readonly EXP_BUCKET="${BUCKET}/${EXPERIMENT}"
readonly FOLDER_NAME="${BENCHMARK}-${FENGINE_NAME}"

gsutil -m rsync -r "${EXP_BUCKET}/binary-folders/${FOLDER_NAME}" "${WORK}"
find "${WORK}" -name "*.sh" -exec chmod 750 {} \;
"${WORK}/runner.sh"
