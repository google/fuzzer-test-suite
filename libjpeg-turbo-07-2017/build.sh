#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && autoreconf -fiv && CXX="clang++ $FUZZ_CXXFLAGS" CC="clang $FUZZ_CXXFLAGS" ./configure && make -j $JOBS)
}

get_git_revision https://github.com/libjpeg-turbo/libjpeg-turbo.git b0971e47d76fdb81270e93bbf11ff5558073350d SRC
build_lib
build_libfuzzer
set -x
clang++ -std=c++11 $SCRIPT_DIR/libjpeg_turbo_fuzzer.cc  $FUZZ_CXXFLAGS -I BUILD BUILD/.libs/libturbojpeg.a $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
