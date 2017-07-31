#!/bin/bash

# gcloud init
cd
sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/gcloud-clang-deps
sudo docker build -t base-image -f ~/input/FTS/engine-comparison/Dockerfile ~/input # --build-arg run_cmd="$1" ~/input
sudo docker run base-image "$1"
