#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD/build && ./autogen.sh && cd .. && CXX="clang++ $FUZZ_CXXFLAGS" CC="clang $FUZZ_CXXFLAGS" CCLD="clang++ $FUZZ_CXXFLAGS"  ./configure && make -j $JOBS)
}

get_git_revision https://github.com/libarchive/libarchive.git 51d7afd3644fdad725dd8faa7606b864fd125f88 SRC
build_lib
build_libfuzzer
set -x
clang++ -std=c++11  -I BUILD/libarchive $SCRIPT_DIR/libarchive_fuzzer.cc  BUILD/.libs/libarchive.a libFuzzer.a -lz -lxml2 -lcrypto -lssl $FUZZ_CXXFLAGS -o $EXECUTABLE_NAME_BASE
