#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

DF="-DFUZZER_DISABLE_SIGNCHECK -Wno-expansion-to-defined"
PATCH=wolfssl_no_sig.patch

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  cp $SCRIPT_DIR/$PATCH BUILD
  (cd BUILD &&
    patch -p1 < ${PATCH} &&
    ./autogen.sh &&
    CC="$CC" ./configure --prefix=`pwd` --exec-prefix=`pwd` \
    CFLAGS="$FUZZ_CXXFLAGS $DF" &&
    make -j $JOBS && make install
  )
}

get_git_tag https://github.com/wolfSSL/wolfssl.git v3.9.6 SRC
build_lib
build_fuzzer
set -x
CERTPATH=`pwd`
WOLFSSL=`pwd`/BUILD
$CXX $CXXFLAGS $SCRIPT_DIR/target.cc $LIB_FUZZING_ENGINE -I$WOLFSSL/include \
     -Wl,-rpath,$WOLFSSL/lib -L$WOLFSSL/lib -lwolfssl \
     -o ${EXECUTABLE_NAME_BASE}${BINARY_NAME_EXT}
