#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./autogen.sh && ./configure && make clean && make all -j $JOBS)
}

get_git_revision git://git.sv.nongnu.org/freetype/freetype2.git cd02d359a6d0455e9d16b87bf9665961c4699538 SRC
build_lib
build_fuzzer

if [[ ! -d seeds ]]; then
  mkdir seeds
  git clone https://github.com/unicode-org/text-rendering-tests.git
  cp text-rendering-tests/fonts/TestKERNOne.otf seeds/
  cp text-rendering-tests/fonts/TestGLYFOne.ttf seeds/
  rm -fr text-rendering-tests
fi

set -x
$CXX $CXXFLAGS -std=c++11 -I BUILD/include -I BUILD/ BUILD/src/tools/ftfuzzer/ftfuzzer.cc BUILD/objs/.libs/libfreetype.a  $LIB_FUZZING_ENGINE -larchive -lz -o $EXECUTABLE_NAME_BASE

