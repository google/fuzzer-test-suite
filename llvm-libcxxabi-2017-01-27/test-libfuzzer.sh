#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
set -x
. $(dirname $0)/../common.sh

rm -rf $CORPUS fuzz-*.log
mkdir $CORPUS
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -jobs=$JOBS -workers=$JOBS $CORPUS $LIBFUZZER_FLAGS
grep "terminate called after throwing an instance of 'std::out_of_range'" fuzz-0.log || exit 1
