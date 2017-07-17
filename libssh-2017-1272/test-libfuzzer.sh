#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x

rm -rf $CORPUS
mkdir $CORPUS

rm -f *.log

[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -max_len=60 -artifact_prefix=$CORPUS/ -jobs=$JOBS -workers=$JOBS $CORPUS
grep "ERROR: LeakSanitizer: detected memory leaks" fuzz-0.log || exit 1


