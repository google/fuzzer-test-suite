#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && make guetzli_static -j $JOBS)
}

get_git_tag https://github.com/google/guetzli.git 9afd0bbb7db0bd3a50226845f0f6c36f14933b6b SRC
build_lib
build_fuzzer
if [[ $FUZZING_ENGINE == "hooks" ]]; then
  # Link ASan runtime so we can hook memcmp et al.
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi
set -x
$CXX $CXXFLAGS -std=c++11 BUILD/fuzz_target.cc -I BUILD/ BUILD/bin/Release/libguetzli_static.a $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
