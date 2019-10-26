#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh

rm -rf $CORPUS fuzz-*.log
mkdir $CORPUS

[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS -jobs=$JOBS -workers=$JOBS $LIBFUZZER_FLAGS $CORPUS seeds
grep "ERROR: LeakSanitizer" fuzz-0.log || exit 1

