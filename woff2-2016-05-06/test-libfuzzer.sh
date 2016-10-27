#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x

# Find the buffer overflow (or OOM) with a seed corpus.
rm -rf $CORPUS
mkdir $CORPUS
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE  -artifact_prefix=$CORPUS/ -max_total_time=1800 -jobs=$JOBS -workers=$JOBS $CORPUS SEED_CORPUS
grep "AddressSanitizer: heap-buffer-overflow\|ERROR: libFuzzer: out-of-memory" fuzz-0.log  || exit 1

# Find OOM bug with an empty seed corpus.
rm -rf $CORPUS-1
mkdir $CORPUS-1
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE  -artifact_prefix=$CORPUS-1/ -max_total_time=600 -jobs=$JOBS -workers=$JOBS $CORPUS-1
grep "ERROR: libFuzzer: out-of-memory" fuzz-0.log || exit 1
