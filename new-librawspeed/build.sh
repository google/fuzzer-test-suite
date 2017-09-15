#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

# CXXFLAGS="$CXXFLAGS -fsanitize=undefined"
# CFLAGS="$CFLAGS -fsanitize=undefined"

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  BUILD_TO="$(pwd)"
  (cd BUILD && mkdir build && cd build && \
cmake \
  -G"Unix Makefiles" -DBINARY_PACKAGE_BUILD=ON \
  -DWITH_PTHREADS=OFF -DWITH_OPENMP=OFF \
  -DWITH_PUGIXML=OFF -DUSE_XMLLINT=OFF -DWITH_JPEG=OFF -DWITH_ZLIB=OFF \
  -DBUILD_TESTING=OFF -DBUILD_TOOLS=OFF -DBUILD_BENCHMARKING=OFF \
  -DCMAKE_BUILD_TYPE=FUZZ -DBUILD_FUZZERS=ON \
  -DLIBFUZZER_ARCHIVE:FILEPATH="${BUILD_TO}/$LIB_FUZZING_ENGINE" \
  -DCMAKE_INSTALL_PREFIX:PATH="${BUILD_TO}" -DCMAKE_INSTALL_BINDIR:PATH="${BUILD_TO}" \
  "${BUILD_TO}/BUILD/" && make -j$JOBS all && make -j$JOBS install)


}
get_git_revision https://github.com/darktable-org/rawspeed.git  44e8b3c2e93a3b64aae35d52b11f4f0e90e26a4d  SRC

build_fuzzer
build_lib


set -x
#$CXX $CXXFLAGS -std=c++11 -I BUILD/liblwgeom BUILD/fuzzers/wkb_import_fuzzer.cpp BUILD/liblwgeom/.libs/liblwgeom.a $LIB_FUZZING_ENGINE -lstdc++ -o $EXECUTABLE_NAME_BASE

