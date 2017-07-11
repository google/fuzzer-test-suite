#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x
rm -rf $CORPUS
mkdir $CORPUS
cp $SCRIPT_DIR/seed.jpg $CORPUS

rm fuzz-*.log

test_source_location() {
  SRC_LOC="$1"
  echo "test_source_location: $SRC_LOC"
  rm -f *.log
  [ -e $EXECUTABLE_NAME_BASE ] && \
    ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -exit_on_src_pos=$SRC_LOC -jobs=$JOBS -workers=$JOBS -print_pcs=1 $CORPUS
  grep "INFO: found line matching '$SRC_LOC'" fuzz-*.log || exit 1
}

test_source_location jdmarker.c:659

