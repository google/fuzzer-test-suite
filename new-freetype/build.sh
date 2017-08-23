#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./autogen.sh && ./configure && make clean && make all -j $JOBS)
}

get_git_tag git://git.sv.nongnu.org/freetype/freetype2.git VER-2-8 SRC
build_lib
build_fuzzer

if [[ ! -d seeds ]]; then
  mkdir seeds
  (cd seeds && wget https://github.com/adobe-fonts/adobe-variable-font-prototype/releases/download/1.001/AdobeVFPrototype.otf)
  git clone https://github.com/unicode-org/text-rendering-tests.git
  cp text-rendering-tests/fonts/* seeds
  rm -fr text-rendering-tests
fi

set -x
$CXX $CXXFLAGS -std=c++11 -I BUILD/include -I BUILD/ BUILD/src/tools/ftfuzzer/ftfuzzer.cc BUILD/objs/.libs/libfreetype.a  $LIB_FUZZING_ENGINE -larchive -lz -o $EXECUTABLE_NAME_BASE

