#!/bin/bash
mkdir TMP_CLANG
cd TMP_CLANG
git clone https://chromium.googlesource.com/chromium/src/tools/clang
cd ..
TMP_CLANG/clang/scripts/update.py
sudo cp -rf  third_party/llvm-build/Release+Asserts/lib/clang /usr/local/lib/
sudo cp -rf  third_party/llvm-build/Release+Asserts/bin/* /usr/local/bin
