#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x
rm -rf $CORPUS
mkdir $CORPUS
rm -f *.log
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -exit_on_src_pos=re2/dfa.cc:474 -exit_on_src_pos=re2/dfa.cc:474  -runs=1000000 -jobs=$JOBS -workers=$JOBS $CORPUS
grep "INFO: found line matching 're2/dfa.cc:474', exiting." fuzz-0.log || exit 1

# Also test mergind here
rm -rf $CORPUS-2
mkdir $CORPUS-2
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE $CORPUS-2 $CORPUS -merge=1 2> log
grep -v DFA log
grep "=== Merge: written [1-9][0-9].* units" log || exit 1


