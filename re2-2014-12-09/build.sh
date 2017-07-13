#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

target_files(){
  TARGET_NAME=target
  TARGET_INCLUDE="-I BUILD/"
  TARGET_LIBRARY="BUILD/obj/libre2.a"
  TARGET_FILE="${SCRIPT_DIR}/${TARGET_NAME}"
  TARGET_C="${TARGET_FILE}.cc ${TARGET_INCLUDE}"
}

. $(dirname $0)/../common.sh $1

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && make clean &&  make -j)
}

get_git_revision https://github.com/google/re2.git 499ef7eff7455ce9c9fae86111d4a77b6ac335de SRC
build_lib
build_fuzzer

set -x

$CXX $FINAL_TARGET $FUZZER_BUILD_FLAGS -lpthread -o ${EXECUTABLE_NAME_BASE}${BINARY_NAME_EXT}
