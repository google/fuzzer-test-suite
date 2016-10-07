// Copyright 2016 Google Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
#include <string>
#include <vector>
#include "libxml/xmlversion.h"
#include "libxml/parser.h"
#include "libxml/HTMLparser.h"
#include "libxml/tree.h"

void ignore (void * ctx, const char * msg, ...) {}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  xmlSetGenericErrorFunc(NULL, &ignore);
  if (auto doc = xmlReadMemory(reinterpret_cast<const char *>(data), size,
                               "noname.xml", NULL, 0))
    xmlFreeDoc(doc);
  return 0;
}
