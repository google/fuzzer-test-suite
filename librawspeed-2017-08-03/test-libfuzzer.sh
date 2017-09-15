#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

set -x
. $(dirname $0)/../common.sh
rm -rf $CORPUS
mkdir $CORPUS

[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -jobs=$JOBS -workers=$JOBS\
  -artifact_prefix=$CORPUS/ -dict=TiffDecoderFuzzer-PefDecoder.dict $CORPUS

grep 'ERROR: libFuzzer: deadly signal' fuzz-0.log || exit 1

