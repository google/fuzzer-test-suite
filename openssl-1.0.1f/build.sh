#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  # This version of openssl has unstable parallel make => Don't use `make -j `.
  (cd BUILD && CC="$CC $CFLAGS" ./config && make clean && make)
}

get_git_tag https://github.com/openssl/openssl.git OpenSSL_1_0_1f SRC
build_lib
build_fuzzer
$CXX $CXXFLAGS $SCRIPT_DIR/target.cc -DCERT_PATH=\"$SCRIPT_DIR/\"  BUILD/libssl.a BUILD/libcrypto.a $LIB_FUZZING_ENGINE -I BUILD/include -o $EXECUTABLE_NAME_BASE
