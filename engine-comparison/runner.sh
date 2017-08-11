#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. metadata.cfg
. parameters.cfg
. fengine.cfg

BINARY=${BENCHMARK}-${FUZZING_ENGINE}
mkdir -p corpus
chmod 750 $BINARY

if [[ FUZZING_ENGINE == "afl" ]]; then
  chmod 750 afl-fuzz
  BINARY="afl-fuzz $BINARY"
fi

./$BINARY $BINARY_RUNTIME_OPTIONS # -workers=$JOBS -jobs=$JOBS -artifact_prefix=corpus

mkdir -p results
while [[ ! -e results/complete.txt ]] : do
  sleep 12
  ls -l corpus > logfile.txt
  go run generator.go
  rm logfile.txt
  gsutil rsync results gs://fuzzer-test-suite/experiment-results/${BINARY}-results
done

go run parser.go finished

