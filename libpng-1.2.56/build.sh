#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

[ ! -e libpng-1.2.56.tar.gz ] && wget https://downloads.sourceforge.net/project/libpng/libpng12/1.2.56/libpng-1.2.56.tar.gz
[ ! -e libpng-1.2.56 ] && tar xf libpng-1.2.56.tar.gz

build_lib() {
  rm -rf BUILD
  cp -rf libpng-1.2.56 BUILD
  (cd BUILD && ./configure &&  make -j)
}

build_lib
build_fuzzer
set -x
$CXX $CXXFLAGS -std=c++11 $SCRIPT_DIR/target.cc BUILD/.libs/libpng12.a $LIB_FUZZING_ENGINE -I BUILD/ -I BUILD -lz -o $EXECUTABLE_NAME_BASE-lf
