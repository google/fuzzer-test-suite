#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps
for f in $(find ~/input/FTS/*.sh);
do
  chmod 750 $f
done
for f in $(find ~/input/FTS/*/*.sh);
do
  chmod 750 $f
done
sudo docker build -t base-image -f ~/input/FTS/engine-comparison/Dockerfile ~/input
sudo docker run --cap-add SYS_PTRACE base-image /work/FTS/engine-comparison/dispatcher.sh

