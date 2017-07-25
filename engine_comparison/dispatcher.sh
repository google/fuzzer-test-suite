#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh

build_engine() {
  # [[ ! -e ~/$FENGINE_CONFIGS_DIR/$1 ]] && echo "cant do" && exit 1
  echo "Building $FUZZING_ENGINE"
  # Probably use another script, to easily use env vars
  #
  # if libfuzzer
  # if afl
}

build_benchmark_using() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2
  # . $FENGINE_CONFIG

  BUILDING_DIR=RUN-${THIS_BENCHMARK}
  rm -rf $BUILDING_DIR
  mkdir $BUILDING_DIR
  cd $BUILDING_DIR
  echo "Filling $BUILDING_DIR"

  # [[ ! -e ~/$FTS/$1/build.sh ]] && echo "cant build" && exit 1
  ~/$FTS/$1/build.sh $FENGINE_NAME $FUZZING_ENGINE

  # copy binaries

  # TODO Add other items eg ./afl-fuzz, seeds
}

BASE_INSTANCE_NAME="FTS-RUNNER"
EXPORT FENGINE_CONFIGS_DIR=${FENGINE_CONFIGS_DIR:-"fuzzing-engine-configs"}

for FENGINE_CONFIG in $(find ~/$FENGINE_CONFIGS_DIR); do
  build_engine $FUZZING_ENGINE
  for BENCHMARK in $ALL_BENCHMARKS; do
    THIS_BENCHMARK=${BENCHMARK}-${FUZZING_ENGINE}
    # n.b. this requires each config file to have a different name
    INSTANCE_NAME=${BASE_INSTANCE_NAME}-${THIS_BENCHMARK}
    build_benchmark_using $BENCHMARK $FUZZING_ENGINE

    gcloud compute instances create $INSTANCE_NAME
    gcloud compute scp --recurse $INSTANCE_NAME ./RUN-${THIS_BENCHMARK}/
    COMMAND="docker build BUILDING-${THIS_BENCHMARK}" # --build-arg dir=/dir
    gcloud compute ssh $INSTANCE_NAME --command=$COMMAND
  done
done


######
# for time in 30s 1m 5m 10m 30m; do
  # sleep $time
  # echo "Information after sleeping $time"
  # tail fuzz-0.log | echo
# done
