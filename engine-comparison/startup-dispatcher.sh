#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on creation of the dispatcher VM.
# Configures dispatcher container and runs the dispatcher script.

sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps:latest
find ~/input/FTS/ -name "*.sh" -exec chmod 750 {} \;
sudo docker build -t base-image \
  -f ~/input/FTS/engine-comparison/Dockerfile-dispatcher ~/input
sudo docker run --cap-add SYS_PTRACE base-image \
  /work/FTS/engine-comparison/dispatcher.sh
