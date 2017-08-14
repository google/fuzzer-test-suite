#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# set -x
. benchmark.cfg
. parameters.cfg
. fengine.cfg

BINARY=${BENCHMARK}-${FUZZING_ENGINE}

rm -fr corpus
mkdir corpus
mkdir results
chmod 750 $BINARY

# All options which are always called here, rather than being left
# to $BINARY_RUNTIME_OPTIONS, are effectively mandatory

if [[ $FUZZING_ENGINE == "afl" ]]; then
  chmod 750 afl-fuzz

  # AFL requires some starter input
  if [[ -d seeds ]]; then
    mkdir seeds
    echo "Input" >> ./seeds/nil_seed
  fi

  ./afl-fuzz $BINARY $BINARY_RUNTIME_OPTIONS -i ./seeds/ -o corpus &

elif [[ $FUZZING_ENGINE == "libfuzzer" ]]; then
  if [[ -d seeds ]]; then
    cp -r seeds/* corpus
  fi

  ./$BINARY $BINARY_RUNTIME_OPTIONS -workers=$JOBS -jobs=$JOBS corpus &
fi

timing=1
while [[ "infinite loop" ]]; do
  sleep 20 # Should be sufficiently long to copy the whole corpus

  # These "corpus-data" files may be unnecessary
  ls -l corpus > results/corpus-data-${timing}
  gsutil rsync results gs://fuzzer-test-suite/experiment-folders/${BINARY}/results

  cp -r corpus corpus-copy
  gsutil rsync corpus-copy gs://fuzzer-test-suite/experiment-folders/${BINARY}/corpus-${timing}
  rm -r corpus-copy

  timing=$(($timing + 1))
done

