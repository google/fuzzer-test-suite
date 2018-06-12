#!/bin/bash
# Copyright 2018 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

MODE=$1
HOOKS_FILE=$2

if [[ -n "${MODE}" ]]; then
  case "${MODE}" in
    asan)
      export FUZZING_ENGINE=libfuzzer
      export CFLAGS="-O2 -fno-omit-frame-pointer -gline-tables-only -fsanitize=address -fsanitize-address-use-after-scope -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
      export CXXFLAGS="${CFLAGS}"
      ;;
    ubsan)
      export FUZZING_ENGINE=libfuzzer
      export CFLAGS="-O2 -fno-omit-frame-pointer -gline-tables-only -fsanitize=undefined -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
      export CXXFLAGS="${CFLAGS}"
      ;;
    hooks)
      if [[ ! -f "${HOOKS_FILE}" ]]; then
        echo "Error: Missing hooks file"
        exit 1
      fi
      export FUZZING_ENGINE=hooks
      export CFLAGS="-O0 -fsanitize-coverage=trace-pc-guard,trace-cmp,trace-gep,trace-div"
      export CXXFLAGS="${CFLAGS}"
      export HOOKS_FILE
      ;;
    *)
      echo "Error: Unknown mode: ${MODE}"
      exit 1
      ;;
  esac
fi

