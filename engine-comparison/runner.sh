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

### all of below vvv to be done by parser.go

BMARK_DONE=""
TIME=0

FUZZ_LOG=fuzz-0.log

while [[ -z $BMARK_DONE ]] : do
  sleep 12
  TIME=$(($TIME+12))

  EXAMINE=$(tail --lines=1 $FUZZ_LOG)

  # Record Coverage
  COVERAGE=$(echo "$EXAMINE" | grep -o "cov: [0-9]*" | grep -o "[0-9]*")
  echo "$TIME,$COVERAGE" >> coverage.txt

  # Record Corpus Size
  # corpus size: X bytes large among Y corpus elements
  CORP_SIZES=$(echo "$EXAMINE" | grep -oi "corp: [0-9]/[a-z0-9]*")
  SIZE_1=$(echo "$CORP_SIZES" | grep -o "[0-9]*/" | tr -d '/')
  SIZE_2=$(echo "$CORP_SIZES" | grep -oi "/[0-9]*[a-z]*" | tr -d '/')
  echo "$TIME,$SIZE_1,$SIZE_2" >> corpus.txt

  # Check if benchmark has been reached
  BMARK_DONE=$(grep "==ERROR==" fuzz-0.log)
done


echo "Bug found at $TIME" > bug-report.txt
echo "---" >> bug-report.txt
LINE_NUMBER=$(grep -n "==ERROR==" fuzz-0.log | grep -o "[0-9][0-9]*:" | head --lines=1)
N_LINES=$(( $(wc -l < fuzz-0.log) - LINE_NUMBER ))
tail --lines=N_LINES fuzz-0.log >> bug-report.txt

