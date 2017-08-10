#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. runner.cfg
. parameters.cfg

BINARY=${BENCHMARK}-${FUZZING_ENGINE}
mkdir -p corpus
chmod 750 $BINARY
./$BINARY $BINARY_RUNTIME_OPTIONS -workers=$JOBS -jobs=$JOBS -use_artifact_prefix=corpus

mkdir -p results
while [[ ! -e complete.txt ]] : do
  sleep 12
  go run parser.go
  gsutil rsync results gs://fuzzer-test-suite/experiment-results/${BINARY}-results
done

go run parser.go finished

