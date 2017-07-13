#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

target_files(){
  TARGET_NAME=cms_transform_fuzzer
  TARGET_INCLUDE="-I BUILD/include/"
  TARGET_LIBRARY="BUILD/src/.libs/liblcms2.a"
  TARGET_FILE="${SCRIPT_DIR}/${TARGET_NAME}"
  TARGET_C="${TARGET_FILE}.c ${TARGET_INCLUDE}"
}

. $(dirname $0)/../common.sh $1

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./autogen.sh && ./configure && make -j $JOBS)
}

get_git_revision https://github.com/mm2/Little-CMS.git f9d75ccef0b54c9f4167d95088d4727985133c52 SRC
build_lib
build_fuzzer

set -x

$CXX $FINAL_TARGET $FUZZER_BUILD_FLAGS -o ${EXECUTABLE_NAME_BASE}${BINARY_NAME_EXT}
