#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

set -x
build_fuzzer
$CC $CFLAGS -c $SCRIPT_DIR/sqlite3.c
$CC $CFLAGS -c $SCRIPT_DIR/ossfuzz.c
$CXX $CXXFLAGS sqlite3.o ossfuzz.o $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
