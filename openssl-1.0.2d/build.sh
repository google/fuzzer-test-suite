#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./config && make clean && make CC="clang $FUZZ_CXXFLAGS"  -j $JOBS)
}

get_git_tag https://github.com/openssl/openssl.git OpenSSL_1_0_2d SRC
build_lib
build_libfuzzer
set -x
clang++ -g $SCRIPT_DIR/target.cc -DCERT_PATH=\"$SCRIPT_DIR/\"  $FUZZ_CXXFLAGS BUILD/libssl.a BUILD/libcrypto.a $LIB_FUZZING_ENGINE -lgcrypt -o $EXECUTABLE_NAME_BASE -I BUILD/include
