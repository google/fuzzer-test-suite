#! /bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

cd
[[ ! -d /input ]] && mkdir /input

gsutil -m rsync -rd gs://fuzzer-test-suite/dispatcher-input /input
gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps

sudo docker build -t base-image -f /input/FTS/engine-comparison/Dockerfile /input
sudo docker run --cap-add SYS_PTRACE base-image /work/FTS/engine-comparison/dispatcher.sh

