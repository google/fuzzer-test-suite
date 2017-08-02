#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD &&
    ./autogen.sh &&
     CCLD="$CXX $CXXFLAGS" ./configure --enable-never-backslash-C --with-match-limit=1000 --with-match-limit-recursion=1000 &&
     make -j
  )
}

get_svn_revision svn://vcs.exim.org/pcre2/code/trunk 183 SRC
build_lib
build_fuzzer
set -x
$CXX $CXXFLAGS $SCRIPT_DIR/target.cc -I BUILD/src -Wl,--whole-archive BUILD/.libs/*.a -Wl,-no-whole-archive $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
