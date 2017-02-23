# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
FROM libfuzzertutorial/base

RUN mkdir -p ~/heartbleed && rm -rf ~/heartbleed/* && cd ~/heartbleed && ~/FTS/openssl-1.0.1f/build.sh && rm -rf BUILD
RUN cd && mkdir -p woff && cd woff && ~/FTS/woff2-2016-05-06/build.sh
RUN mkdir -p ~/libxml && rm -rf ~/libxml/* && cd ~/libxml && ~/FTS/libxml2-v2.9.2/build.sh && rm -rf BUILD
RUN mkdir -p ~/openssl-1.0.2d && rm -rf ~/openssl-1.0.2d/* && cd ~/openssl-1.0.2d && ~/FTS/openssl-1.0.2d/build.sh && rm -rf BUILD
RUN mkdir ~/pcre2 && cd ~/pcre2 && ~/FTS/pcre2-10.00/build.sh
