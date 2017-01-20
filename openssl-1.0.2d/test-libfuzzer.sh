#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
set -x
. $(dirname $0)/../common.sh
rm -rf $CORPUS
mkdir $CORPUS
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -max_len=512  -jobs=$JOBS -workers=$JOBS $CORPUS
grep 'Assertion `strcmp(openssl_results.exptmod, gcrypt_results.exptmod)==0. failed.' fuzz-0.log || exit 1


# Test -minimize_crash=1.
# We know that this crasher minimizes to 132 bytes.
# If we manage to minimize it further the test will fail,
# but we will learn something new.
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE $SCRIPT_DIR/crash-12ae1af0c82252420b5f780bc9ed48d3ba05109e  -minimize_crash=1 -runs=1000000 2> min.log
grep CRASH_MIN min.log
grep "CRASH_MIN: failed to minimize beyond ./minimized-from-.* (1.. bytes), exiting" min.log || exit 1
