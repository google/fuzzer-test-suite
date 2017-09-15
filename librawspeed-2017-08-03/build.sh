#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  mkdir BUILD/build
  mkdir BUILD/tmp
  CWD="$(pwd)"
  (cd BUILD/build && \
  cmake \
  -G"Unix Makefiles" -DBINARY_PACKAGE_BUILD=ON \
  -DWITH_PTHREADS=OFF -DWITH_OPENMP=OFF \
  -DWITH_PUGIXML=OFF -DUSE_XMLLINT=OFF -DWITH_JPEG=OFF -DWITH_ZLIB=OFF \
  -DBUILD_TESTING=OFF -DBUILD_TOOLS=OFF -DBUILD_BENCHMARKING=OFF \
  -DCMAKE_BUILD_TYPE=FUZZ -DBUILD_FUZZERS=ON \
  -DLIBFUZZER_ARCHIVE:FILEPATH="${CWD}/$LIB_FUZZING_ENGINE" \
  -DCMAKE_INSTALL_PREFIX:PATH="${CWD}/BUILD/tmp" -DCMAKE_INSTALL_BINDIR:PATH="${CWD}/BUILD/tmp" \
  "${CWD}/BUILD/" && make -j$JOBS all && make -j$JOBS install)

}

get_git_revision https://github.com/darktable-org/rawspeed.git  44e8b3c2e93a3b64aae35d52b11f4f0e90e26a4d  SRC

# RawSpeed is highly integrated with fuzzing, and needs to link to the fuzzing
# engine before building
build_fuzzer
build_lib

# build_lib makes many targets: now pick the one for this benchmark
cp BUILD/tmp/TiffDecoderFuzzer-PefDecoder .
cp BUILD/tmp/TiffDecoderFuzzer-PefDecoder.dict .
rm -fr BUILD/tmp

