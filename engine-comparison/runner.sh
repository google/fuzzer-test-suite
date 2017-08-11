#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. metadata.cfg
. parameters.cfg
. fengine.cfg

BINARY=${BENCHMARK}-${FUZZING_ENGINE}
mkdir ./corpus
mkdir ./results
chmod 750 $BINARY

if [[ FUZZING_ENGINE == "afl" ]]; then
  chmod 750 afl-fuzz
  ./afl-fuzz $BINARY $BINARY_RUNTIME_OPTIONS -o corpus/ &
elif [[ FUZZING_ENGINE == "libfuzzer" ]]; then
  ./$BINARY $BINARY_RUNTIME_OPTIONS -workers=1 -jobs=1 corpus/ &
fi

while [[ "infinite loop" ]]; do
  sleep 12
  ls -l corpus > results/corpusdata
  gsutil rsync results gs://fuzzer-test-suite/experiment-folders/${BINARY}/results
  gsutil rsync corpus gs://fuzzer-test-suite/experiment-folders/${BINARY}/corpus

done

#mkdir -p results
#while : do
#  sleep 12
#  ls -l corpus > logfile.txt
#  # rm logfile.txt
#  gsutil -m rsync -P corpus gs://fuzzer-test-suite/experiment-folders/${BINARY}/corpus
#done

