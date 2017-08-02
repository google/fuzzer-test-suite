#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && mkdir build && cd build && cmake -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CXXFLAGS" -DWITH_STATIC_LIB=ON  .. &&  make -j $JOBS)
}

get_git_revision git://git.libssh.org/projects/libssh.git 7c79b5c154ce2788cf5254a62468fee5112f7640 SRC
build_lib
build_fuzzer
set -x
$CXX $CXXFLAGS -std=c++11 "$SCRIPT_DIR/libssh_server_fuzzer.cc" -I BUILD/include/ BUILD/build/src/libssh.a $LIB_FUZZING_ENGINE -lcrypto -lgss -lz -o $EXECUTABLE_NAME_BASE

