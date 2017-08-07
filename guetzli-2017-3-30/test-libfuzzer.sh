#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x
rm -rf $CORPUS

cp -r $SCRIPT_DIR/seeds $CORPUS

[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -max_len=180 -use_value_profile=1 -close_fd_mask=3 -dict=$SCRIPT_DIR/jpeg.dict -artifact_prefix=$CORPUS/ -jobs=$JOBS -workers=$JOBS $CORPUS
grep "ERROR: libFuzzer: deadly signal" fuzz-0.log || exit 1
