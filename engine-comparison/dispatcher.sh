#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh
. ${SCRIPT_DIR}/common-harness.sh

build_engine() {
  # [[ ! -e ~/$FENGINE_CONFIGS_DIR/$1 ]] && echo "cant do" && exit 1
  # All of this code will probably be in a separate script

  FENGINE_CONFIG=$1

  echo "Building $FENGINE_CONFIG"
  FENGINE_NAME=$(basename $FENGINE_CONFIG)
  export ENGINE_DIR=$WORK/fuzz-engines/${FENGINE_NAME}
  rm -rf $ENGINE_DIR
  mkdir $ENGINE_DIR

  # Fuzzing activities go here
}

build_benchmark_using() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2
  FENGINE_NAME=$(basename $FENGINE_CONFG)

  echo "Filling $BUILDING_DIR"
  BUILDING_DIR=$WORK/BUILD-${BENCHMARK}-WITH-${FENGINE_NAME}
  rm -rf $BUILDING_DIR
  mkdir $BUILDING_DIR

  # Do fuzzing things here
  # [[ ! -e ~/FTS/$BENCHMARK/build.sh ]] && echo "cant build" && exit 1
  # $WORK/FTS/$BENCHMARK/build.sh $FUZZING_ENGINE

  export SEND_DIR=$WORK/SEND-${BENCHMARK}-WITH-${FENGINE_NAME}
  rm -rf $SEND_DIR
  mkdir $SEND_DIR
  echo "Test file" > $SEND_DIR/example.txt
  # Then construct the directory to send here, e.g.
  # cp ${BENCHMARK}-${FUZZING_ENGINE} $SEND_DIR
  # copy seeds, afl-fuzz, etc

  rm -rf $BUILDING_DIR
}

handle_benchmark() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2
  THIS_BENCHMARK=${BENCHMARK}-WITH-$(basename {FENGINE_NAME}) # Just for convenience
  build_benchmark_using $BENCHMARK $FENGINE_CONFIG

  INSTANCE_NAME=FTS-RUNNER-${THIS_BENCHMARK}
  gcloud compute instances create $INSTANCE_NAME --zone=$GCLOUD_ZONE
  # TODO robust ssh here (equiv scp)
  gcloud compute scp $WORK/SEND-${THIS_BENCHMARK}/ ${INSTANCE_NAME}:~/input --recurse --zone=$GCLOUD_ZONE

  RUNNER_COMMAND="mv ~/input/SEND-${THIS_BENCHMARK} ~/input && ~/input/run.sh"
  # run.sh will need an argument, the workers script
  gcloud compute ssh $INSTANCE_NAME --command=$RUNNER_COMMAND --zone=$GCLOUD_ZONE
}

mv $WORK/tmp-configs $WORK/fengine-configs
mkdir $WORK/fuzz-engines

for FENGINE_CONFIG in $(find $WORK/fengine-configs/*); do
  # this requires each config file to have a different name
  build_engine $FENGINE_CONFIG

  for BENCHMARK in $ALL_BENCHMARKS; do
    handle_benchmark $BENCHMARK $FENGINE_CONFIG &
  done
done

# rm -rf $WORK/SEND*

######
# for time in 30s 1m 5m 10m 30m; do
  # sleep $time
  # echo "Information after sleeping $time"
  # tail fuzz-0.log | echo
# done
