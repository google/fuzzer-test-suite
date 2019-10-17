#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

set -x
rm -rf $CORPUS fuzz-*.log
mkdir $CORPUS

test_source_location() {
  SRC_LOC="$1"
  echo "test_source_location: $SRC_LOC"
  [ -e $EXECUTABLE_NAME_BASE ] && \
    ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -exit_on_src_pos=$SRC_LOC -jobs=$JOBS -workers=$JOBS $LIBFUZZER_FLAGS $CORPUS seeds
  grep "INFO: found line matching '$SRC_LOC'" fuzz-*.log || (date && exit 1)
}

# test_source_location ttinterp.c:2186
test_source_location ttgload.c:1710:7
