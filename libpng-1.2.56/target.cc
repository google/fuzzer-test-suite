// Copyright 2016 Google Inc. All Rights Reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
#include <stddef.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>

#define PNG_INTERNAL  // For PNG_FLAG_CRC_CRITICAL_MASK, etc.
#include "png.h"

struct BufState {
  const uint8_t* data;
  size_t bytes_left;
};

void user_read_data(png_structp png_ptr, png_bytep data, png_size_t length) {
  BufState* buf_state = static_cast<BufState*>(png_get_io_ptr(png_ptr));
  if (length > buf_state->bytes_left) {
    png_error(png_ptr, "read error");
  }
  memcpy(data, buf_state->data, length);
  buf_state->bytes_left -= length;
  buf_state->data += length;
}

static const int kPngHeaderSize = 8;

struct ScopedPngObject {
  ~ScopedPngObject() {
    if (row && png_ptr) {
      png_free(png_ptr, row);
    }
    if (png_ptr && info_ptr) {
      png_destroy_read_struct(&png_ptr, &info_ptr, nullptr);
    }
    delete buf_state;
  }
  png_infop info_ptr = nullptr;
  png_voidp row = 0;
  png_structp png_ptr = nullptr;
  BufState *buf_state = nullptr;
};

bool DetectLargeSize(const uint8_t *data, size_t size) {
  uint8_t *ihdr = reinterpret_cast<uint8_t *>(memmem(data, size, "IHDR", 4));
  if (!ihdr) return false;
  if (ihdr + 12 > data + size) return false;
  uint32_t W = *(uint32_t*)(ihdr + 4);
  uint32_t H = *(uint32_t*)(ihdr + 8);
  W = __builtin_bswap32(W);
  H = __builtin_bswap32(H);
  uint64_t WxH = static_cast<uint64_t>(W) * H;
  if (WxH > 100000ULL) {
    // fprintf(stderr, "ZZZ %zu %u %u\n", WxH, W, H);
    return true;
  }
  return false;
}

// Fuzzing entry point. Roughly follows the libpng book example:
// http://www.libpng.org/pub/png/book/chapter13.html
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size < kPngHeaderSize) {
    return 0;
  }
  ScopedPngObject O;
  if (png_sig_cmp(const_cast<uint8_t*>(data), 0, kPngHeaderSize)) {
    // not a PNG.
    return 0;
  }

  // if (DetectLargeSize(data, size)) return 0;

  auto &png_ptr = O.png_ptr;
  png_ptr = png_create_read_struct
    (PNG_LIBPNG_VER_STRING, nullptr, nullptr, nullptr);
  assert(png_ptr);

  png_ptr->flags &= ~PNG_FLAG_CRC_CRITICAL_MASK;
  png_ptr->flags |= PNG_FLAG_CRC_CRITICAL_IGNORE;

  png_ptr->flags &= ~PNG_FLAG_CRC_ANCILLARY_MASK;
  png_ptr->flags |= PNG_FLAG_CRC_ANCILLARY_NOWARN;

  auto &info_ptr = O.info_ptr;
  info_ptr = png_create_info_struct(png_ptr);
  assert(info_ptr);

  // Setting up reading from buffer.
  auto &buf_state = O.buf_state;
  buf_state = new BufState();
  buf_state->data = data + kPngHeaderSize;
  buf_state->bytes_left = size - kPngHeaderSize;
  png_set_read_fn(png_ptr, buf_state, user_read_data);
  png_set_sig_bytes(png_ptr, kPngHeaderSize);
  int passes = 0;

  // libpng error handling.
  if (setjmp(png_ptr->jmpbuf)) {
    return 0;
  }

  // png_ptr->mode & PNG_HAVE_IDAT
  // Reading
  png_read_info(png_ptr, info_ptr);

  png_uint_32 width, height;
  int bit_depth, color_type, interlace_type, compression_type;
  int filter_type;

  if (!png_get_IHDR(png_ptr, info_ptr, &width, &height,
        &bit_depth, &color_type, &interlace_type,
        &compression_type, &filter_type)) {
    return 0;
  }

  if (height * width > 2000000) return 0;  // This is going to be too slow.


  passes = png_set_interlace_handling(png_ptr);
  png_start_read_image(png_ptr);

  O.row = png_malloc(png_ptr, png_get_rowbytes(png_ptr, info_ptr));

  for (int pass = 0; pass < passes; ++pass) {
    for (png_uint_32 y = 0; y < height; ++y) {
      png_read_row(png_ptr, static_cast<png_bytep>(O.row), NULL);
    }
  }
  return 0;
}
