#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Don't allow to call these scripts from their directories.
[ -e $(basename $0) ] && echo "PLEASE USE THIS SCRIPT FROM ANOTHER DIR" && exit 1

# Ensure that fuzzing engine, if defined, is valid
FUZZING_ENGINE=${FUZZING_ENGINE:-"libfuzzer"}
POSSIBLE_FUZZING_ENGINE="libfuzzer afl coverage fsanitize_fuzzer hooks"
!(echo "$POSSIBLE_FUZZING_ENGINE" | grep -w "$FUZZING_ENGINE" > /dev/null) && \
  echo "USAGE: Error: If defined, FUZZING_ENGINE should be one of the following:
  $POSSIBLE_FUZZING_ENGINE. However, it was defined as $FUZZING_ENGINE" && exit 1

SCRIPT_DIR=$(dirname $0)
EXECUTABLE_NAME_BASE=$(basename $SCRIPT_DIR)-${FUZZING_ENGINE}
LIBFUZZER_SRC=${LIBFUZZER_SRC:-$(dirname $(dirname $SCRIPT_DIR))/Fuzzer}
AFL_SRC=${AFL_SRC:-$(dirname $(dirname $SCRIPT_DIR))/AFL}
COVERAGE_FLAGS="-O0 -fsanitize-coverage=trace-pc-guard"
FUZZ_CXXFLAGS="-O2 -fno-omit-frame-pointer -g -fsanitize=address -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
CORPUS=CORPUS-$EXECUTABLE_NAME_BASE
JOBS=${JOBS:-"8"}


export CC=${CC:-"clang"}
export CXX=${CXX:-"clang++"}
export LIB_FUZZING_ENGINE="libFuzzingEngine-${FUZZING_ENGINE}.a"

if [[ $FUZZING_ENGINE == "fsanitize_fuzzer" ]]; then
  FSANITIZE_FUZZER_FLAGS="-O2 -fno-omit-frame-pointer -g -fsanitize=address,fuzzer-no-link"
  export CFLAGS=${CFLAGS:-$FSANITIZE_FUZZER_FLAGS}
  export CXXFLAGS=${CXXFLAGS:-$FSANITIZE_FUZZER_FLAGS}
elif [[ $FUZZING_ENGINE == "coverage" ]]; then
  export CFLAGS=${CFLAGS:-$COVERAGE_FLAGS}
  export CXXFLAGS=${CXXFLAGS:-$COVERAGE_FLAGS}
else
  export CFLAGS=${CFLAGS:-"$FUZZ_CXXFLAGS"}
  export CXXFLAGS=${CXXFLAGS:-"$FUZZ_CXXFLAGS"}
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
  $CC $CFLAGS -c -w $AFL_SRC/llvm_mode/afl-llvm-rt.o.c
  $CXX $CXXFLAGS -std=c++11 -O2 -c ${LIBFUZZER_SRC}/afl/afl_driver.cpp -I$LIBFUZZER_SRC
  ar r $LIB_FUZZING_ENGINE afl_driver.o afl-llvm-rt.o.o
  rm *.o
}

build_libfuzzer() {
  $LIBFUZZER_SRC/build.sh
  mv libFuzzer.a $LIB_FUZZING_ENGINE
}

# Uses the capability for "fsanitize=fuzzer" in the current clang
build_fsanitize_fuzzer() {
  LIB_FUZZING_ENGINE="-fsanitize=fuzzer"
}

# This provides a build with no fuzzing engine, just to measure coverage
build_coverage () {
  $CC $COVERAGE_FLAGS -c $LIBFUZZER_SRC/standalone/StandaloneFuzzTargetMain.c
  ar rc $LIB_FUZZING_ENGINE StandaloneFuzzTargetMain.o
}

# Build with user-defined main and hooks.
build_hooks() {
  LIB_FUZZING_ENGINE=libFuzzingEngine-hooks.o
  $CXX $CXXFLAGS -c $HOOKS_FILE -o $LIB_FUZZING_ENGINE
}

build_fuzzer() {
  echo "Building with $FUZZING_ENGINE"
  build_${FUZZING_ENGINE}
}

