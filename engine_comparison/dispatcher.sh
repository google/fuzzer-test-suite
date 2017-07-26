#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh

build_engine() {
  # [[ ! -e ~/$FENGINE_CONFIGS_DIR/$1 ]] && echo "cant do" && exit 1

  # All of this code will probably be in a separate script

  FENGINE_CONFIG=$1

  echo "Building $FENGINE_CONFIG"
  export ENGINE_DIR=$WORK/fuzz-engines/${FENGINE_CONFIG}
  rm -rf $ENGINE_DIR
  mkdir $ENGINE_DIR

  # Fuzzing activities go here

}

build_benchmark_using() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2

  echo "Filling $BUILDING_DIR"
  BUILDING_DIR=$WORK/BUILD-${BENCHMARK}-WITH-${FENGINE_CONFIG}
  rm -rf $BUILDING_DIR
  mkdir $BUILDING_DIR

  # Do fuzzing things here
  # [[ ! -e ~/FTS/$BENCHMARK/build.sh ]] && echo "cant build" && exit 1
  # $WORK/FTS/$BENCHMARK/build.sh $FUZZING_ENGINE

  export SEND_DIR=$WORK/SEND-${BENCHMARK}-WITH-${FENGINE_CONFIG}
  rm -rf $SEND_DIR
  mkdir $SEND_DIR
  # Then construct the directory to send here, e.g.
  # cp ${BENCHMARK}-${FUZZING_ENGINE} $SEND_DIR
  # copy seeds, afl-fuzz, etc

  rm -rf $BUILDING_DIR
}

BASE_INSTANCE_NAME="FTS-RUNNER"

for FENGINE_CONFIG in $(find $WORK/fengine-configs); do
  build_engine $FENGINE_CONFIG
  for BENCHMARK in $ALL_BENCHMARKS; do
    # n.b. this requires each config file to have a different name
    build_benchmark_using $BENCHMARK $FENGINE_CONFIG

    THIS_BENCHMARK=${BENCHMARK}-WITH-${FENGINE_CONFIG} # Just for convenience

    INSTANCE_NAME=${BASE_INSTANCE_NAME}-${THIS_BENCHMARK}
    gcloud compute instances create $INSTANCE_NAME

    gcloud compute scp --recurse $WORK/SEND-${THIS_BENCHMARK}/ ${INSTANCE_NAME}:/input

    RUNNER_COMMAND="docker build --build-arg run-script=runner.sh /input"
    gcloud compute ssh $INSTANCE_NAME --command=$RUNNER_COMMAND
  done
done

# rm -rf $WORK/SEND*

######
# for time in 30s 1m 5m 10m 30m; do
  # sleep $time
  # echo "Information after sleeping $time"
  # tail fuzz-0.log | echo
# done
