Finds a multi-byte-write-heap-buffer-overflow in [Woff2](https://github.com/google/woff2)

Time to find: < 20 minutes.

```
ERROR: AddressSanitizer: heap-buffer-overflow
WRITE of size 6707 at 0x62300000534d thread T0
    #0 0x4a95d3 in __asan_memcpy
    #1 0x62fa5c in woff2::Buffer::Read(unsigned char*, unsigned long) src/./buffer.h:86:7
    #2 0x62fa5c in woff2::(anonymous namespace)::ReconstructGlyf src/woff2_dec.cc:500
    #3 0x62fa5c in woff2::(anonymous namespace)::ReconstructFont src/woff2_dec.cc:917
    #4 0x62fa5c in woff2::ConvertWOFF2ToTTF src/woff2_dec.cc:1282
```


