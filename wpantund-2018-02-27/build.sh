#!/bin/bash
# Copyright 2018 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  if [[ -f $LIB_FUZZING_ENGINE ]]; then
    cp $LIB_FUZZING_ENGINE BUILD/src/wpantund/
    cp $LIB_FUZZING_ENGINE BUILD/src/ncp-spinel/
  fi
  if [[ $FUZZING_ENGINE == "hooks" ]]; then
    # Link ASan runtime so we can hook memcmp et al.
    LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
  fi
  (cd BUILD && ./bootstrap.sh && ./configure \
    --enable-fuzz-targets             \
    --disable-shared                  \
    --enable-static                   \
    CC="${CC}"                        \
    CXX="${CXX}"                      \
    FUZZ_LIBS="${LIB_FUZZING_ENGINE}" \
    FUZZ_CFLAGS="${CFLAGS}"           \
    FUZZ_CXXFLAGS="${CXXFLAGS}"       \
    LDFLAGS="-lpthread"               \
    && make -j $JOBS)
}

get_git_revision https://github.com/openthread/wpantund.git \
  7fea6d7a24a52f6a61545610acb0ab8a6fddf503 SRC
build_fuzzer || exit 1
build_lib || exit 1

if [[ ! -d seeds ]]; then
  cp -r BUILD/etc/fuzz-corpus/wpantund-fuzz seeds
fi
cp BUILD/src/wpantund/wpantund-fuzz $EXECUTABLE_NAME_BASE
