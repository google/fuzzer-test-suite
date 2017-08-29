#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# set -x
. benchmark.cfg
. parameters.cfg
. fengine.cfg

FENGINE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/fengine -H "Metadata-Flavor: Google")

BINARY=${BENCHMARK}-${FUZZING_ENGINE}

rm -fr corpus results
mkdir corpus
mkdir results
# seeds comes from dispatcher.sh, if it exists
chmod 750 $BINARY

# All options which are always called here, rather than being left
# to $BINARY_RUNTIME_OPTIONS, are effectively mandatory

if [[ $FUZZING_ENGINE == "afl" ]]; then
  chmod 750 afl-fuzz

  # AFL requires some starter input
  if [[ ! -d seeds ]]; then
    mkdir seeds
  fi
  if [[ !$(find seeds -type f) ]]; then
    echo "Input" > ./seeds/nil_seed
  fi
  
  EXEC_CMD="AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 ./afl-fuzz $BINARY_RUNTIME_OPTIONS -i ./seeds/ -o corpus -- $BINARY &"

elif [[ $FUZZING_ENGINE == "libfuzzer" ]]; then
  if [[ -d seeds ]]; then
    cp -r seeds/* corpus
  fi

  EXEC_CMD="./$BINARY $BINARY_RUNTIME_OPTIONS -workers=$JOBS -jobs=$JOBS corpus &"
fi

mkdir corpus-archives

# Folder name to sync to (convenient)
SYNC_TO=${BENCHMARK}-${FENGINE_NAME}
# WAIT_PERIOD should be longer than the whole loop, otherwise a sync cycle will be missed
WAIT_PERIOD=20
CYCLE=1

# Now, begin
$EXEC_CMD
NEXT_SYNC=$(($SECONDS + $WAIT_PERIOD)) # =$SECONDS # Make beginning measurement?

# This works for libfuzzer, tbd for AFL:
while [[ ! -f crash* ]]; do
# while [[ "infinite loop" ]]; do

  # Ensure that measurements happen every $WAIT_PERIOD
  SLEEP_TIME=$(($NEXT_SYNC - $SECONDS))
  sleep $SLEEP_TIME

  # Snapshot
  cp -r corpus corpus-copy

  echo "VM_SECONDS=$SECONDS" > results/seconds-${CYCLE}
  ls -l corpus-copy > results/corpus-data-${CYCLE}
  tar -cvzf corpus-archives/corpus-archive-${CYCLE}.tar.gz corpus-copy
  gsutil -m rsync -rPd results gs://fuzzer-test-suite/experiment-folders/${SYNC_TO}/results
  gsutil -m rsync -rPd corpus-archives gs://fuzzer-test-suite/experiment-folders/${SYNC_TO}/corpus

  # Done with snapshot
  rm -r corpus-copy

  # Skip cycle if need be
  while [[ $(($NEXT_SYNC < $SECONDS)) == 1 ]]; do
    NEXT_SYNC=$(($NEXT_SYNC + $WAIT_PERIOD))
  done

  CYCLE=$(($CYCLE + 1))
done

