#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on creation of the dispatcher VM.
# Configures dispatcher container and runs the dispatcher script.

find ~/input/FTS/ -name "*.sh" -exec chmod 750 {} \;

# Start container with necessary environment.
sudo docker run --rm -d --cap-add SYS_PTRACE -e INSTANCE_NAME="${HOSTNAME}" \
  --name=dispatcher-container gcr.io/fuzzer-test-suite/dispatcher \
  tail -f /dev/null

# Copy input files to container
for f in ~/input/*; do
  sudo docker cp "${f}" dispatcher-container:/work/
done

# Start dispatcher script in container
sudo docker exec dispatcher-container /work/FTS/engine-comparison/dispatcher.sh
