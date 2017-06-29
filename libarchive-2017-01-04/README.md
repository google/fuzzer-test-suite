This is a benchmark for finding a
[heap-buffer-overflow bug](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=382) in
[libarchive](https://github.com/libarchive/libarchive).

The bug can be found in under 1 hour, when starting from the provided seed.
```
==115561==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x616000000bc8 at pc 0x00000059259b bp 0x7ffde8169f10 sp 0x7ffde8169f08
READ of size 1 at 0x616000000bc8 thread T0
    #0 0x59259a in xstrpisotime libarchive/archive_read_support_format_warc.c:537:9
    #1 0x58f7e6 in _warc_rdrtm libarchive/archive_read_support_format_warc.c:757:8
    #2 0x58f7e6 in _warc_rdhdr libarchive/archive_read_support_format_warc.c:273
    #3 0x4f46c1 in _archive_read_next_header2 libarchive/archive_read.c:648:7
    #4 0x4f43dd in _archive_read_next_header libarchive/archive_read.c:686:8
    #5 0x4eb0e8 in LLVMFuzzerTestOneInput libarchive-2017-01-04/libarchive_fuzzer.cc:48:10

```
