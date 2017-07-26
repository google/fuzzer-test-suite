#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh

build_engine() {
  # [[ ! -e ~/$FENGINE_CONFIGS_DIR/$1 ]] && echo "cant do" && exit 1

  # All of this code will probably be in a separate script

  FENGINE_CONFIG=$1
  . $FENGINE_CONFIG
  echo "Building $FENGINE_CONFIG"
  # export ENGINE_DIR=${ENGINE_DIR}
}

build_benchmark_using() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2

  # Write a new script here, probably
  #
  . $FENGINE_CONFIG

  BUILDING_DIR=BUILD-${BENCHMARK}-WITH-${FENGINE_CONFIG}
  rm -rf $BUILDING_DIR
  mkdir $BUILDING_DIR
  cd $BUILDING_DIR
  echo "Filling $BUILDING_DIR"

  # [[ ! -e ~/FTS/$1/build.sh ]] && echo "cant build" && exit 1
  ~/FTS/$BENCHMARK/build.sh $FUZZING_ENGINE

  # export SEND_DIR=SEND-${THIS_BENCHMARK}
  # cp ${BENCHMARK}-${FUZZING_ENGINE} $SEND_DIR

  # copy seeds, afl-fuzz
}

BASE_INSTANCE_NAME="FTS-RUNNER"

for FENGINE_CONFIG in $(find ./fengine-configs); do
  build_engine $FENGINE_CONFIG
  for BENCHMARK in $ALL_BENCHMARKS; do
    THIS_BENCHMARK=${BENCHMARK}-${FENGINE_CONFIG}
    # n.b. this requires each config file to have a different name
    build_benchmark_using $BENCHMARK $FENGINE_CONFIG

    INSTANCE_NAME=${BASE_INSTANCE_NAME}-${THIS_BENCHMARK}
    gcloud compute instances create $INSTANCE_NAME

    gcloud compute ssh $INSTANCE_NAME --command="mkdir /input"
    gcloud compute scp --recurse ./RUN-${THIS_BENCHMARK}/ ${INSTANCE_NAME}:/input/RUN-${THIS_BENCHMARK}
    # probably want to scp SEND-$THIS_BENCHMARK instead

    RUNNER_COMMAND="docker build -f /RUN-${THIS_BENCHMARK} --build-arg run-script=runner.sh /input"
    gcloud compute ssh $INSTANCE_NAME --command=$RUNNER_COMMAND
  done
done


######
# for time in 30s 1m 5m 10m 30m; do
  # sleep $time
  # echo "Information after sleeping $time"
  # tail fuzz-0.log | echo
# done
