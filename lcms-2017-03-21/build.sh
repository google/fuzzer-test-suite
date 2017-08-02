#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./autogen.sh && ./configure && make -j $JOBS)
}

get_git_revision https://github.com/mm2/Little-CMS.git f9d75ccef0b54c9f4167d95088d4727985133c52 SRC
build_lib
build_fuzzer
set -x
$CXX $CXXFLAGS ${SCRIPT_DIR}/cms_transform_fuzzer.c -I BUILD/include/ BUILD/src/.libs/liblcms2.a $LIB_FUZZING_ENGINE -o $EXECUTABLE_NAME_BASE
