#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

[ ! -e libpng-1.2.56.tar.gz ] && wget ftp://ftp.simplesystems.org/pub/libpng/png/src/libpng12/libpng-1.2.56.tar.gz
[ ! -e libpng-1.2.56 ] && tar xf libpng-1.2.56.tar.gz

build_lib() {
  rm -rf BUILD
  cp -rf libpng-1.2.56 BUILD
  (cd BUILD && ./configure CC="clang" CFLAGS="$FUZZ_CXXFLAGS" &&  make -j)
}

build_lib
build_libfuzzer
set -x
clang++ -g -std=c++11 $FUZZ_CXXFLAGS $SCRIPT_DIR/target.cc BUILD/.libs/libpng12.a $LIB_FUZZING_ENGINE -I BUILD/ -I BUILD -lz -o $EXECUTABLE_NAME_BASE-lf
