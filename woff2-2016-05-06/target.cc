// Copyright 2016 Google Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
#include <stddef.h>
#include <stdint.h>

#include "woff2_dec.h"

// Entry point for LibFuzzer.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  std::string buf;
  woff2::WOFF2StringOut out(&buf);
  out.SetMaxSize(30 * 1024 * 1024);
  woff2::ConvertWOFF2ToTTF(data, size, &out);
  return 0;
}
