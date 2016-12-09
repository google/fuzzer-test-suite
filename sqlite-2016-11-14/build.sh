#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_libfuzzer
clang -c $FUZZ_CXXFLAGS $SCRIPT_DIR/sqlite3.c
clang -c $FUZZ_CXXFLAGS $SCRIPT_DIR/ossfuzz.c
clang++ sqlite3.o ossfuzz.o libFuzzer.a $FUZZ_CXXFLAGS -o $EXECUTABLE_NAME_BASE
