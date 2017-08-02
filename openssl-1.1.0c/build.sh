#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && CC="$CC $CFLAGS" ./config && make clean && make -j $JOBS)
}

get_git_tag https://github.com/openssl/openssl.git OpenSSL_1_1_0c SRC
build_lib
build_fuzzer
set -x
$CC $CFLAGS -DFuzzerTestOneInput=LLVMFuzzerTestOneInput -c -g BUILD/fuzz/bignum.c -I BUILD/include
$CXX $CXXFLAGS bignum.o BUILD/libssl.a BUILD/libcrypto.a $LIB_FUZZING_ENGINE -lgcrypt -o $EXECUTABLE_NAME_BASE
