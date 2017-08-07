#!/bin/bash

cd
sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps
sudo docker build -t base-image -f ~/input/FTS/engine-comparison/Dockerfile ~/input
sudo docker run --cap-add SYS_PTRACE base-image "$1"
