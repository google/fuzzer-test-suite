#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  (cd BUILD && ./autogen.sh && CCLD="$CXX $CXXFLAGS" ./configure --disable-shared && make -j $JOBS)
}

get_git_tag https://gitlab.gnome.org/GNOME/libxml2.git v2.9.2 SRC
get_git_revision https://github.com/google/afl e9be6bce2282e8db95221c9a17fd10aba9e901bc afl
build_lib
build_fuzzer

cp afl/dictionaries/xml.dict .

if [[ $FUZZING_ENGINE == "hooks" ]]; then
  # Link ASan runtime so we can hook memcmp et al.
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi
set -x
$CXX $CXXFLAGS -std=c++11  $SCRIPT_DIR/target.cc -I BUILD/include BUILD/.libs/libxml2.a $LIB_FUZZING_ENGINE -lz -o $EXECUTABLE_NAME_BASE
