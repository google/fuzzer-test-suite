#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# set -x
. benchmark.cfg
. parameters.cfg
. fengine.cfg

FENGINE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/fengine -H "Metadata-Flavor: Google")

BINARY=${BENCHMARK}-${FUZZING_ENGINE}

rm -fr corpus
mkdir corpus
mkdir results
# seeds comes from dispatcher.sh
chmod 750 $BINARY

# All options which are always called here, rather than being left
# to $BINARY_RUNTIME_OPTIONS, are effectively mandatory

if [[ $FUZZING_ENGINE == "afl" ]]; then
  chmod 750 afl-fuzz

  # AFL requires some starter input
  if [[ (! -d seeds) || !$(find seeds -type f) ]]; then
    echo "Input" >> ./seeds/nil_seed
  fi

  ./afl-fuzz $BINARY_RUNTIME_OPTIONS -i ./seeds/ -o corpus -- $BINARY &

elif [[ $FUZZING_ENGINE == "libfuzzer" ]]; then
  if [[ -d seeds ]]; then
    cp -r seeds/* corpus
  fi

  ./$BINARY $BINARY_RUNTIME_OPTIONS -workers=$JOBS -jobs=$JOBS corpus &
fi

SYNC_TO=${BENCHMARK}-${FENGINE_NAME}
timing=1


# This works for libfuzzer, tbd for AFL:
# #while [[ ! -e crash* ]]; do
while [[ "infinite loop" ]]; do
  sleep 20 # Should be sufficiently long to copy the whole corpus

  # These "corpus-data" files may be unnecessary
  ls -l corpus > results/corpus-data-${timing}
  gsutil -m rsync -rd results gs://fuzzer-test-suite/experiment-folders/${SYNC_TO}/results

  cp -r corpus corpus-copy
  gsutil -m rsync -rd corpus-copy gs://fuzzer-test-suite/experiment-folders/${SYNC_TO}/corpus-${timing}
  rm -r corpus-copy

  timing=$(($timing + 1))
done

