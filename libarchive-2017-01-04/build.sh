#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD/build && ./autogen.sh && cd .. && ./configure --disable-shared --without-nettle && make -j $JOBS)
}

get_git_revision https://github.com/libarchive/libarchive.git 51d7afd3644fdad725dd8faa7606b864fd125f88 SRC
build_lib
build_fuzzer

if [[ $FUZZING_ENGINE == "hooks" ]]; then
  # Link ASan runtime so we can hook memcmp et al.
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi
set -x
$CXX $CXXFLAGS -std=c++11 $SCRIPT_DIR/libarchive_fuzzer.cc -I BUILD/libarchive BUILD/.libs/libarchive.a $LIB_FUZZING_ENGINE -lz  -lbz2 -lxml2 -lcrypto -lssl -llzma -o $EXECUTABLE_NAME_BASE
