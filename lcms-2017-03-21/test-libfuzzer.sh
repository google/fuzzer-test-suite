#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
set -x
. $(dirname $0)/../common.sh
rm -rf $CORPUS
mkdir $CORPUS

cp $SCRIPT_DIR/seed $CORPUS

[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -jobs=$JOBS -workers=$JOBS $CORPUS
grep 'ERROR: AddressSanitizer: heap-buffer-overflow' fuzz-0.log || exit 1

