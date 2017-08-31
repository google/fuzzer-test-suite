#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && make fuzzers -Ctest -j $JOBS)
}

get_git_revision https://github.com/nlohmann/json.git b04543ecc58188a593f8729db38c2c87abd90dc3 SRC
build_lib
build_fuzzer

$CXX $CXXFLAGS -std=c++11 -I BUILD/src BUILD/test/src/fuzzer-parse_json.cpp $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
