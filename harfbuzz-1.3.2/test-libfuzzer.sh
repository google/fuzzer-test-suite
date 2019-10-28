#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh
set -x
rm -rf $CORPUS fuzz-*.log
mkdir $CORPUS
[ -e $EXECUTABLE_NAME_BASE ] && ./$EXECUTABLE_NAME_BASE -artifact_prefix=$CORPUS/ -max_total_time=1800 -jobs=$JOBS -workers=$JOBS $LIBFUZZER_FLAGS $CORPUS seeds
grep "hb-buffer.cc:419: bool hb_buffer_t::move_to(unsigned int): Assertion `i <= out_len + (len - idx)' failed" fuzz-0.log
