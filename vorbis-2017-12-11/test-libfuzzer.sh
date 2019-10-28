#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x

rm -rf $CORPUS fuzz-*.log
mkdir $CORPUS
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -use_value_profile=1 -artifact_prefix=$CORPUS/ -jobs=$JOBS -workers=$JOBS $LIBFUZZER_FLAGS $CORPUS $SCRIPT_DIR/seeds
grep "AddressSanitizer: heap-buffer-overflow\|AddressSanitizer: SEGV on unknown address" fuzz-0.log || exit 1
