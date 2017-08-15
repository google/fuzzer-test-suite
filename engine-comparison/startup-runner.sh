#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

mkdir -p ~/input
BENCHMARK=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/benchmark -H "Metadata-Flavor: Google")
FENGINE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/fengine -H "Metadata-Flavor: Google")

FOLDER_NAME=${BENCHMARK}-with-${FENGINE_NAME}

gsutil -m rsync -rd gs://fuzzer-test-suite/binary-folders/${FOLDER_NAME} ~/input
sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps

for f in $(find ~/input/*.sh); do
  chmod 750 $f
done

sudo docker build -t base-image ~/input
sudo docker run --cap-add SYS_PTRACE base-image /work/runner.sh

