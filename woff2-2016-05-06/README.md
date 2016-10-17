Finds a multi-byte-write-heap-buffer-overflow
[bug](https://bugs.chromium.org/p/chromium/issues/detail?id=609042)
in [Woff2](https://github.com/google/woff2)

Time to find: < 20 minutes, requires the seed corpus (downloaded as `SEED_CORPUS` dir).
Reproducer provided.

```
ERROR: AddressSanitizer: heap-buffer-overflow
WRITE of size 6707 at 0x62300000534d thread T0
    #0 0x4a95d3 in __asan_memcpy
    #1 0x62fa5c in woff2::Buffer::Read(unsigned char*, unsigned long) src/./buffer.h:86:7
    #2 0x62fa5c in woff2::(anonymous namespace)::ReconstructGlyf src/woff2_dec.cc:500
    #3 0x62fa5c in woff2::(anonymous namespace)::ReconstructFont src/woff2_dec.cc:917
    #4 0x62fa5c in woff2::ConvertWOFF2ToTTF src/woff2_dec.cc:1282
```

Also hits OOMs. Time to find < 1 minute, with an empty corpus.
Reproducer provided.


```
==30135== ERROR: libFuzzer: out-of-memory (used: 2349Mb; limit: 2048Mb)
   To change the out-of-memory limit use -rss_limit_mb=<N>

   Live Heap Allocations: 3749936468 bytes from 2254 allocations; showing top 95%
   3747609600 byte(s) (99%) in 1 allocation(s)
   ...
   #6 0x62e8f6 in woff2::ConvertWOFF2ToTTF src/woff2_dec.cc:1274
   #7 0x660731 in LLVMFuzzerTestOneInput FTS/woff2-2016-05-06/target.cc:13:3
```

