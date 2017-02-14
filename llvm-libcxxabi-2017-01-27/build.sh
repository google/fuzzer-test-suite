#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

get_svn_revision http://llvm.org/svn/llvm-project/libcxxabi/trunk 293329 SRC
build_libfuzzer

clang++ -std=c++11 SRC/fuzz/cxa_demangle_fuzzer.cpp SRC/src/cxa_demangle.cpp -I SRC/include \
  $FUZZ_CXXFLAGS libFuzzer.a -o $EXECUTABLE_NAME_BASE
