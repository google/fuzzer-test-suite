#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# Find heartbleed.
. $(dirname $0)/../common.sh
set -x
[ -e $EXECUTABLE_NAME_BASE ]  && ./$EXECUTABLE_NAME_BASE -max_total_time=300 2>&1 | tee log
grep -Pzo "(?s)ERROR: AddressSanitizer: heap-buffer-overflow.*READ of size.*#1 0x.* in tls1_process_heartbeat .*ssl/t1_lib.c:2586" log
