#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_CXX_FLAGS="$CXXFLAGS -Wno-error=main" && make -j)
}

get_git_revision https://github.com/google/boringssl.git  894a47df2423f0d2b6be57e6d90f2bea88213382 SRC
build_lib
build_fuzzer
set -x
$CXX $CXXFLAGS -I BUILD/include BUILD/fuzz/privkey.cc ./BUILD/ssl/libssl.a ./BUILD/crypto/libcrypto.a $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
