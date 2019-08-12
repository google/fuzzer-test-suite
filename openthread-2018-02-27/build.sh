#!/bin/bash
# Copyright 2018 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../custom-build.sh $1 $2
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  # workaround https://github.com/google/fuzzer-test-suite/issues/131
  sed -i 's/-Wshadow//g' BUILD/configure.ac BUILD/third_party/mbedtls/repo.patched/CMakeLists.txt
  [[ -f $LIB_FUZZING_ENGINE ]] && cp $LIB_FUZZING_ENGINE BUILD/tests/fuzz/
  if [[ $FUZZING_ENGINE == "hooks" ]]; then
    # Link ASan runtime so we can hook memcmp et al.
    LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
  fi
  (cd BUILD && ./bootstrap && ./configure \
    --disable-shared                    \
    --enable-fuzz-targets               \
    --enable-application-coap           \
    --enable-border-router              \
    --enable-cert-log                   \
    --enable-channel-monitor            \
    --enable-child-supervision          \
    --enable-commissioner               \
    --enable-dhcp6-client               \
    --enable-dhcp6-server               \
    --enable-dns-client                 \
    --enable-diag                       \
    --enable-dns-client                 \
    --enable-jam-detection              \
    --enable-joiner                     \
    --enable-legacy                     \
    --enable-mac-filter                 \
    --enable-mtd-network-diagnostic     \
    --enable-raw-link-api               \
    --enable-service                    \
    --enable-tmf-proxy                  \
    --disable-docs                      \
    && make V=1 -j $JOBS)
}

rm -rf SRC
[[ -z "${REVISION}" ]] && REVISION="79c4830c3c17369909e0906d8f455ecf2be4b6aa"
get_git_revision https://github.com/openthread/openthread.git "${REVISION}" SRC
build_fuzzer || exit 1
build_lib || exit 1

if [[ ! -d seeds-radio ]]; then
  cp -r BUILD/tests/fuzz/corpora/radio-receive-done seeds-radio
fi
cp BUILD/tests/fuzz/ip6-send-fuzzer $EXECUTABLE_NAME_BASE-ip6
cp BUILD/tests/fuzz/radio-receive-done-fuzzer $EXECUTABLE_NAME_BASE-radio
