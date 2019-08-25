#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS -Wno-deprecated-declarations" -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_CXX_FLAGS="$CXXFLAGS -Wno-error=main" && make -j $JOBS)
}

get_git_revision https://github.com/google/boringssl.git  894a47df2423f0d2b6be57e6d90f2bea88213382 SRC
build_lib
build_fuzzer

if [[ ! -d seeds ]]; then
  mkdir seeds
  cp BUILD/fuzz/privkey_corpus/* seeds/
fi

if [[ $FUZZING_ENGINE == "hooks" ]]; then
  # Link ASan runtime so we can hook memcmp et al.
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi
set -x
$CXX $CXXFLAGS -I BUILD/include BUILD/fuzz/privkey.cc ./BUILD/ssl/libssl.a ./BUILD/crypto/libcrypto.a -lpthread $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
