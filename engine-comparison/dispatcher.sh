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

  # TODO: make these gsutil cp?
  cp $WORK/FTS/engine-comparison/Dockerfile $SEND_DIR
  cp $WORK/FTS/engine-comparison/runner.sh $SEND_DIR
  cp $WORK/FTS/engine-comparison/config/parameters.cfg $SEND_DIR
  cp $FENGINE_CONFIG $SEND_DIR/fengine.cfg

  echo "BENCHMARK=$BENCHMARK" > $SEND_DIR/benchmark.cfg

  # TODO: ensure all seeds are in $BENCHMARK/seeds
  if [[ -d $WORK/FTS/$BENCHMARK/seeds ]]; then
    cp -r $WORK/FTS/$BENCHMARK/seeds $SEND_DIR
  fi

  if [[ $FUZZING_ENGINE == "afl" ]]; then
    cp ${AFL_SRC}/afl-fuzz $SEND_DIR
  fi

  rm -rf $BUILDING_DIR
}

# Dispatcher specific create_or_start fields
dispatcher_cos () {
  INSTANCE_NAME=$1
  BENCHMARK=$2
  FENGINE_NAME=$3
  create_or_start $INSTANCE_NAME "benchmark=${BENCHMARK},fengine=${FENGINE_NAME}"\
    "startup-script=$WORK/FTS/engine-comparison/startup-runner.sh"
}
handle_benchmark() {
  BENCHMARK=$1
  FENGINE_CONFIG=$2
  # Just for convenience
  FENGINE_NAME=$(basename ${FENGINE_CONFIG})
  THIS_BENCHMARK=${BENCHMARK}-with-${FENGINE_NAME}

  build_benchmark_using $BENCHMARK $FENGINE_CONFIG $THIS_BENCHMARK
  gsutil -m rsync -rd $SEND_DIR ${GSUTIL_BUCKET}/binary-folders/$THIS_BENCHMARK
  # GCloud instance names must match the following regular expression:
  # '[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?'
  INSTANCE_NAME=$(echo "fts-runner-${THIS_BENCHMARK}" | \
    tr '[:upper:]' '[:lower:]' | tr -d '.')
  dispatcher_cos $INSTANCE_NAME $BENCHMARK $FENGINE_NAME
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

# TODO here: reset fengine-config env vars (?)
############# DONE building
rm -rf $WORK/send $WORK/build
############# NOW wait for experiment results

# Make a coverage build for a benchmark
make_measurer () {
  BENCHMARK=$1

  BUILDING_DIR=$WORK/coverage-builds/${BENCHMARK}
  mkdir -p $BUILDING_DIR
  cd $BUILDING_DIR
  FUZZING_ENGINE=coverage $WORK/FTS/${BENCHMARK}/build.sh
}

# Process a corpus, generate a human readable report, send the report to gsutil
# Processing includes: decompress, use sancov.py, etc
measure_coverage () {
  FENGINE_CONFIG=$1
  FENGINE_NAME=$(basename $FENGINE_CONFIG)
  BENCHMARK=$2
  CYCLE=$3

  CORPUS_DIR=$WORK/measurement-folders/$BENCHMARK/corpus
  SANCOV_DIR=$WORK/measurement-folders/$BENCHMARK/sancovs
  REPORT_DIR=$WORK/measurement-folders/$BENCHMARK/reports
  rm -fr $CORPUS_DIR $SANCOV_DIR
  mkdir -p $CORPUS_DIR $SANCOV_DIR $REPORT_DIR

  cd $CORPUS_DIR
  # tar flags specify location to extract contents to (CORPUS_DIR)
  tar -xvf $WORK/experiment-folders/${BENCHMARK}-${FENGINE_NAME}/corpus/corpus-archive-${CYCLE}.tar.gz -C $CORPUS_DIR --strip-components=1

  # Generate individual sancovs
  cd $SANCOV_DIR
  for fl in $(find $CORPUS_DIR -type f); do
    UBSAN_OPTIONS=coverage=1 $WORK/coverage-builds/${BENCHMARK}/${BENCHMARK}-coverage $fl
  done

  # Finish generating human readable report
  cd $REPORT_DIR
  MERGED_NAME=merged-${CYCLE}.sancov
  $WORK/coverage-builds/sancov.py merge ${SANCOV_DIR}/* > $MERGED_NAME
  echo $($WORK/coverage-builds/sancov.py print $MERGED_NAME) > ${REPORT_DIR}/readable-${CYCLE}.txt
  # "readable.txt" should be more readable. Currently, just a list of PCs
  # Report generation goes >here<
  # Could include calls to external scripts in Golang, HTML, etc
  gsutil -m rsync -rd $REPORT_DIR ${GSUTIL_BUCKET}/reports/${BENCHMARK}
}

mkdir -p $WORK/coverage-builds

# Choice of preference: sancov.py over sancov CLI
if [[ ! -f $WORK/coverage-builds/sancov.py ]]; then
  cd $WORK/coverage-builds
  wget http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/sanitizer_common/scripts/sancov.py
  chmod 750 $WORK/coverage-builds/sancov.py
fi

for BENCHMARK in $BENCHMARKS; do
  make_measurer $BENCHMARK
done

set -x

mkdir -p $WORK/experiment-folders
mkdir -p $WORK/measurement-folders

# WAIT_PERIOD should be the same as in runner.sh. It can be longer, but then there
# will be a backlog of corpus archives to parse through even after the runner is
# done. If it is shorter than in runner.sh, code will probably breal
WAIT_PERIOD=20
CYCLE=1

NEXT_SYNC=$(($SECONDS + $WAIT_PERIOD))

# TODO: better "while" condition?
# Maybe not: just end dispatcher VM when done
while [[ "infinite loop" ]]; do
  SLEEP_TIME=$(($NEXT_SYNC - $SECONDS))
  sleep $SLEEP_TIME

  # Prevent calling measure_coverage before runner VM begins
  if [[ $(gsutil ls ${GSUTIL_BUCKET} | grep experiment-folders) ]]; then
    gsutil -m rsync -rd ${GSUTIL_BUCKET}/experiment-folders $WORK/experiment-folders
    for BENCHMARK in $BENCHMARKS; do
      for FENGINE_CONFIG in $(find ${WORK}/fengine-configs -type f); do
        measure_coverage $FENGINE_CONFIG $BENCHMARK $CYCLE
      done
    done
    CYCLE=$(($CYCLE + 1))
  fi

  # Skip cycle if need be
  while [[ $(($NEXT_SYNC < $SECONDS)) == 1 ]]; do
    NEXT_SYNC=$(($NEXT_SYNC + $WAIT_PERIOD))
  done
done

