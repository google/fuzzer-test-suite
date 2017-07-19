#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/common.sh
PARENT_DIR="RUN_EVERY_BENCHMARK"
LOGS_1="./${PARENT_DIR}/RUNDIR-*/fuzz-0.log"
LOGS_2="./${PARENT_DIR}/RUNDIR-*/log"

less $LOGS_1
less $LOGS_2
