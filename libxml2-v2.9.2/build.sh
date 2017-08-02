#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./autogen.sh && CCLD="$CXX $CXXFLAGS" ./configure && make -j $JOBS)
}

get_git_tag git://git.gnome.org/libxml2  v2.9.2 SRC
get_git_revision https://github.com/mcarpenter/afl be3e88d639da5350603f6c0fee06970128504342 afl
build_lib
build_fuzzer
set -x
$CXX $CXXFLAGS -std=c++11  $SCRIPT_DIR/target.cc -I BUILD/include BUILD/.libs/libxml2.a $LIB_FUZZING_ENGINE -lz -o $EXECUTABLE_NAME_BASE
