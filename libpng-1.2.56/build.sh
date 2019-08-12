#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

[ ! -e libpng-1.2.56.tar.gz ] && wget https://downloads.sourceforge.net/project/libpng/libpng12/older-releases/1.2.56/libpng-1.2.56.tar.gz
[ ! -e libpng-1.2.56 ] && tar xf libpng-1.2.56.tar.gz

build_lib() {
  rm -rf BUILD
  cp -rf libpng-1.2.56 BUILD
  (cd BUILD && ./configure --disable-shared &&  make -j $JOBS)
}

build_lib || exit 1
build_fuzzer || exit 1
if [[ $FUZZING_ENGINE == "hooks" ]]; then
  # Link ASan runtime so we can hook memcmp et al.
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi
set -x
$CXX $CXXFLAGS -std=c++11 $SCRIPT_DIR/target.cc BUILD/.libs/libpng12.a $LIB_FUZZING_ENGINE -I BUILD/ -I BUILD -lz -o $EXECUTABLE_NAME_BASE
$CXX $CXXFLAGS -std=c++11 $SCRIPT_DIR/target.cc BUILD/.libs/libpng12.a $LIB_FUZZING_ENGINE -I BUILD/ -I BUILD -lz -o $EXECUTABLE_NAME_BASE-structure-aware \
  -include $SCRIPT_DIR/png_mutator.h -DPNG_MUTATOR_DEFINE_LIBFUZZER_CUSTOM_MUTATOR -DSTANDALONE_TARGET=$STANDALONE_TARGET
