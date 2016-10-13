#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && cmake  -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER=clang -DCMAKE_C_FLAGS="$FUZZ_CXXFLAGS" && make -j)
}

get_git_revision https://github.com/google/boringssl.git  894a47df2423f0d2b6be57e6d90f2bea88213382 SRC
build_lib
build_libfuzzer
clang++ -I BUILD/include $FUZZ_CXXFLAGS BUILD/fuzz/privkey.cc ./BUILD/ssl/libssl.a ./BUILD/crypto/libcrypto.a libFuzzer.a -o $EXECUTABLE_NAME_BASE
