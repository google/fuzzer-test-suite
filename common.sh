#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Don't allow to call these scripts from their directories.
[ -e $(basename $0) ] && echo "PLEASE USE THIS SCRIPT FROM ANOTHER DIR" && exit 1

# Ensure that argument, if present, is either "libfuzzer" or "afl"
FUZZER=${1-"libfuzzer"}
[[ $FUZZER != "libfuzzer" ]] && [[ $FUZZER != "afl" ]] && echo "USAGE: If present, argument \$1 should be either 'afl' or 'libfuzzer'" && exit 1
echo "Building with $FUZZER"

SCRIPT_DIR=$(dirname $0)
EXECUTABLE_NAME_BASE=$(basename $SCRIPT_DIR)
LIBFUZZER_SRC=$(dirname $(dirname $SCRIPT_DIR))/Fuzzer
AFL_DRIVER=$LIBFUZZER_SRC/afl/afl_driver.cpp
AFL_SRC=$(dirname $(dirname $SCRIPT_DIR))/AFL
FUZZ_CXXFLAGS="-O2 -fno-omit-frame-pointer -g -fsanitize=address -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
CORPUS=CORPUS-$EXECUTABLE_NAME_BASE
JOBS=8

CC="clang"
CXX="clang++"
CFLAGS="$FUZZ_CXXFLAGS"
CXXFLAGS="$FUZZ_CXXFLAGS"

# Additional build flags (e.g. for libFuzzer) can be passed to build.sh as $UNIQUE_BUILD

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
  $CC -c -w $AFL_SRC/llvm_mode/afl-llvm-rt.o.c
  $CXX -g -fsanitize-coverage=trace-pc-guard $TARGET_FILE $TARGET_INCLUDE -c

  UNIQUE_BUILD="$AFL_DRIVER afl-llvm-rt.o.o ${TARGET_NAME}.o $UNIQUE_BUILD"
  BINARY_NAME_EXT="_${FUZZER}"
}

build_libfuzzer() {
  $LIBFUZZER_SRC/build.sh

  UNIQUE_BUILD="${TARGET_FILE} libFuzzer.a $UNIQUE_BUILD"
}

build_fuzzer() {
  build_${FUZZER}
}

build_binary() {
  $CXX $CXXFLAGS $UNIQUE_BUILD -o ${EXECUTABLE_NAME_BASE}${BINARY_NAME_EXT}
}
