#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# Don't allow to call these scripts from their directories.
#[ -e $(basename $0) ] && echo "PLEASE USE THIS SCRIPT FROM ANOTHER DIR" && exit 1

# call these scripts from their directories.
if not [ -e $(basename $0) ]; then
	echo "PLEASE USE THIS SCRIPT FROM sub-directories" && exit 1
fi

#SCRIPT_DIR=$(dirname $0)
SCRIPT_DIR=$(pwd)
EXECUTABLE_NAME_BASE=$(basename $SCRIPT_DIR)'-fuzzer'
#LIBFUZZER_SRC=$(dirname $(dirname $SCRIPT_DIR))/Fuzzer
LIBFUZZER_SRC=$(dirname $SCRIPT_DIR)/Fuzzer
FUZZ_CXXFLAGS="-O2 -fno-omit-frame-pointer -g -fsanitize=address -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
CORPUS=CORPUS-$EXECUTABLE_NAME_BASE
JOBS=8

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

build_libfuzzer() {
  $LIBFUZZER_SRC/build.sh
}
