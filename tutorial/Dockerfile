# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
FROM ubuntu:16.04
RUN apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get install -y git sudo
WORKDIR /root
RUN git clone https://github.com/google/fuzzer-test-suite.git FTS && ./FTS/tutorial/install-deps.sh  && ./FTS/tutorial/install-clang.sh
RUN svn co http://llvm.org/svn/llvm-project/llvm/trunk/lib/Fuzzer && Fuzzer/build.sh
