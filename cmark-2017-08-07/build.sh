#!/bin/bash -e
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

get_git_revision https://github.com/commonmark/cmark 61b51fa7c8ec635eee19a16c6aa38c39093a0572 SRC
build_libfuzzer

export LIB_FUZZER_PATH="`pwd`/libFuzzer.a"
cd SRC
pwd
CC=`which clang` make libFuzzer
