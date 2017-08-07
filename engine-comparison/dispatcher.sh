#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh
. ${SCRIPT_DIR}/common-harness.sh


build_engine() {

  FENGINE_CONFIG=$1
  [[ ! -e $FENGINE_CONFIG ]] && echo \
    "Error: build_engine function called for FENGINE_CONFIG=$FENGINE_CONFIG,\
    but this file can't be found" && exit 1
  echo "Creating fuzzing engine: $FENGINE_CONFIG"
  FENGINE_NAME=$(basename $FENGINE_CONFIG)
  FENGINE_DIR=$WORK/fengine-builds/${FENGINE_NAME}
  rm -rf $FENGINE_DIR
  mkdir $FENGINE_DIR

  . $FENGINE_CONFIG
  # Build either engine

  if [[ $FUZZING_ENGINE == "libfuzzer" ]]; then

    if [[ ! -d ${LIBFUZZER_SRC}/standalone ]]; then
      echo "Checking out libFuzzer"
      svn co http://llvm.org/svn/llvm-project/llvm/trunk/lib/Fuzzer $WORK/Fuzzer
      LIBFUZZER_SRC=$WORK/Fuzzer
    fi

  elif [[ $FUZZING_ENGINE == "afl" ]]; then
    # [[ ! -d $LIBFUZZER_SRC ]] && echo "Can't do AFL before libfuzzer" && break
    if [[ ! -d ${LIBFUZZER_SRC}/afl ]]; then
      mkdir -p ${LIBFUZZER_SRC}/afl
      svn co http://llvm.org/svn/llvm-project/llvm/trunk/lib/Fuzzer/afl ${LIBFUZZER_SRC}/afl
    fi
    echo "Building a version of AFL"
    cd $WORK/fengine-builds
    wget http://lcamtuf.coredump.cx/afl/releases/afl-latest.tgz
    tar -xvf afl-latest.tgz -C $FENGINE_DIR --strip-components=1
    (cd $FENGINE_DIR && make)
    rm afl-latest.tgz
    cd
    export AFL_SRC=$FENGINE_DIR
  fi
}

build_benchmark_using() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2
  THIS_BENCHMARK=$3

  BUILDING_DIR=$WORK/build/${THIS_BENCHMARK}
  echo "Filling $BUILDING_DIR"
  rm -rf $BUILDING_DIR
  mkdir $BUILDING_DIR

  cd $BUILDING_DIR
  . $FENGINE_CONFIG
  $WORK/FTS/$BENCHMARK/build.sh
  cd

  export SEND_DIR=$WORK/send/${THIS_BENCHMARK}
  rm -rf $SEND_DIR
  mkdir $SEND_DIR

  cp ${BUILDING_DIR}/${BENCHMARK}-${FUZZING_ENGINE} $SEND_DIR
  if [[ -e $WORK/FTS/$BENCHMARK/seed ]]; then
    cp seed $SEND_DIR
  fi

  if [[ $FUZZING_ENGINE == "afl" ]]; then
    cp ${AFL_SRC}/afl-fuzz $SEND_DIR
  fi

  rm -rf $BUILDING_DIR
}


handle_benchmark() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2
  THIS_BENCHMARK=${BENCHMARK}-with-$(basename ${FENGINE_CONFIG}) # Just for convenience

  build_benchmark_using $BENCHMARK $FENGINE_CONFIG $THIS_BENCHMARK
  gsutil rsync -r $SEND_DIR ${GSUTIL_BUCKET}/binary-folders/$THIS_BENCHMARK
  # GCloud instance names must match the following regular expression:
  # '[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?'
  INSTANCE_NAME=$(echo "fts-runner-${THIS_BENCHMARK}" | \
    tr '[:upper:]' '[:lower:]' | tr -d '.')
  create_or_start $INSTANCE_NAME ./FTS/engine-comparison/runner-startup-script.sh
}

cd

mkdir $WORK/fengine-builds
mkdir $WORK/build
mkdir $WORK/send

# Stripped down equivalent of "gcloud init"
gcloud auth activate-service-account $SERVICE_ACCOUNT \
  --key-file="$WORK/FTS/engine-comparison/config/autogen-PRIVATE-key.json"
gcloud config set project fuzzer-test-suite


# This config file defines $BMARKS
. $WORK/FTS/engine-comparison/config/bmarks.cfg
# Now define $BENCHMARKS
if [[ $BMARKS == 'all' ]]; then
  for b in $(find ${SCRIPT_DIR}/../*/build.sh -type f); do
    BENCHMARKS="$BENCHMARKS $(basename $(dirname $b))"
  done
elif [[ $BMARKS == 'small' ]]; then
  BENCHMARKS="c-ares-CVE-2016-5180 re2-2014-12-09"
elif [[ $BMARKS == 'none' ]]; then
  BENCHMARKS=""
  #elif [[ $BMARKS == 'other alias' ]]; do
else
  BENCHMARKS="$(echo $BMARKS | tr ',' ' ')"
fi


# Main working loops
for FENGINE_CONFIG in $(find ${WORK}/fengine-configs/*); do
  build_engine $FENGINE_CONFIG
  for BENCHMARK in $BENCHMARKS; do
    handle_benchmark $BENCHMARK $FENGINE_CONFIG
  done
done

# rm -rf $WORK/SEND*

######
# for time in 30s 1m 5m 10m 30m; do
  # sleep $time
  # echo "Information after sleeping $time"
  # tail fuzz-0.log | echo
# done
