# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");


FROM ubuntu:16.04
RUN apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get install -y git sudo
# All dependencies for benchmarks

RUN ~/run.sh

