#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh $1

TARGET_NAME="target"
TARGET_FILE="${SCRIPT_DIR}/${TARGET_NAME}.cc"
TARGET_INCLUDE="-I BUILD/"
UNIQUE_BUILD="$UNIQUE_BUILD $TARGET_INCLUDE BUILD/obj/libre2.a -lpthread"

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && make clean &&  make -j)
}

get_git_revision https://github.com/google/re2.git 499ef7eff7455ce9c9fae86111d4a77b6ac335de SRC
build_lib
build_fuzzer
set -x
build_binary
