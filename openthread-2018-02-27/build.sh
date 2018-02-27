#!/bin/bash
# Copyright 2018 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
. $(dirname $0)/../common.sh

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  [[ -f $LIB_FUZZING_ENGINE ]] && cp $LIB_FUZZING_ENGINE BUILD/tests/fuzz/
  (cd BUILD && ./bootstrap && ./configure \
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
    && make -j $JOBS)
}

get_git_revision https://github.com/openthread/openthread.git \
  79c4830c3c17369909e0906d8f455ecf2be4b6aa SRC
build_fuzzer
build_lib

if [[ ! -d seeds-radio-receive-done ]]; then
  cp -r BUILD/tests/fuzz/corpora/radio-receive-done seeds-radio-receive-done
fi
for f in ip6-send radio-receive-done; do
  cp BUILD/tests/fuzz/$f-fuzzer $EXECUTABLE_NAME_BASE-$f
done
