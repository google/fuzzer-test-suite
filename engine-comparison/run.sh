#!/bin/bash

# gcloud init
cd
sudo gcloud docker -- pull gcr.io/fuzzer-test-suite/clang-deps-image
sudo docker build -f ~/input/FTS/engine-comparison/Dockerfile --build-arg run_cmd="$1" ~/input
