#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Don't allow to call these scripts from their directories.
[ -e $(basename $0) ] && echo "PLEASE USE THIS SCRIPT FROM ANOTHER DIR" && exit 1

# Ensure that argument, if present, is either "libfuzzer" or "afl"
FUZZER=${1-"libfuzzer"}
[[ $FUZZER != "libfuzzer" ]] && [[ $FUZZER != "afl" ]] && echo "USAGE: Enter 'afl' as argument \$1 to build using AFL" && exit 1

SCRIPT_DIR=$(dirname $0)
EXECUTABLE_NAME_BASE=$(basename $SCRIPT_DIR)
LIBFUZZER_SRC=$(dirname $(dirname $SCRIPT_DIR))/Fuzzer
AFL_DRIVER=$LIBFUZZER_SRC/afl/afl_driver.cpp
AFL_HOME=$(dirname $(dirname $SCRIPT_DIR))/AFL
FUZZ_CXXFLAGS="-O2 -fno-omit-frame-pointer -g -fsanitize=address -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
CORPUS=CORPUS-$EXECUTABLE_NAME_BASE
JOBS=8

target_files
echo "Building with $FUZZER"

CC="clang"
CXX="clang++"
CFLAGS=""
CXXFLAGS=""

# Additional build flags e.g. for libFuzzer can be pre-defined with FUZZER_BUILD_FLAGS
FUZZER_BUILD_FLAGS="$FUZZER_BUILD_FLAGS $TARGET_LIBRARY"

if [[ $FUZZER == "afl" ]]
then
  FUZZER_BUILD_FLAGS="$FUZZER_BUILD_FLAGS $AFL_DRIVER afl-llvm-rt.o.o"
  FINAL_TARGET="${TARGET_NAME}.o ${TARGET_INCLUDE}"
  BINARY_NAME_EXT="_${FUZZER}"
fi

if [[ $FUZZER == "libfuzzer" ]]
then
  CXXFLAGS=$FUZZ_CXXFLAGS
  CFLAGS=$CXXFLAGS
  CC="$CC $CXXFLAGS"
  CXX="$CXX $CXXFLAGS"
  FUZZER_BUILD_FLAGS="$FUZZER_BUILD_FLAGS libFuzzer.a"
  FINAL_TARGET=$TARGET_C
fi

get_git_revision() {
  GIT_REPO="$1"
  GIT_REVISION="$2"
  TO_DIR="$3"
  [ ! -e $TO_DIR ] && git clone $GIT_REPO $TO_DIR && (cd $TO_DIR && git reset --hard $GIT_REVISION)
}

get_git_tag() {
  GIT_REPO="$1"
  GIT_TAG="$2"
  TO_DIR="$3"
  [ ! -e $TO_DIR ] && git clone $GIT_REPO $TO_DIR && (cd $TO_DIR && git checkout $GIT_TAG)
}

get_svn_revision() {
  SVN_REPO="$1"
  SVN_REVISION="$2"
  TO_DIR="$3"
  [ ! -e $TO_DIR ] && svn co -r$SVN_REVISION $SVN_REPO $TO_DIR
}

build_afl() {
  $CC -c -w $AFL_HOME/llvm_mode/afl-llvm-rt.o.c
  $CXX -g -fsanitize-coverage=trace-pc-guard $TARGET_C -c
}

build_libfuzzer() {
  $LIBFUZZER_SRC/build.sh
}

build_fuzzer() {
  build_${FUZZER}
}
