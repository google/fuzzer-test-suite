This is a benchmark for finding a
[heap-buffer-overflow bug](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=382) in
[libarchive](https://github.com/libarchive/libarchive).

The bug can be found in under 5 minutes through fuzzing.
```
==30873==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60c0000008f5
at pc 0x000000437e03 bp 0x7fffbe94a6b0 sp 0x7fffbe949e50
READ of size 6 at 0x60c0000008f5 thread T0
    #0 0x437e02 in memcpy
    #1 0x634c42 in fuzzer::TracePC::AddValueForMemcmp Fuzzer/FuzzerTracePC.cpp:267:11
    #2 0x432988 in __interceptor_strncmp
    #3 0x560365 in detect_form libarchive/archive_read_support_format_mtree.c:724:14
    #4 0x4ec7a8 in choose_format libarchive/archive_read.c:711:10
    #5 0x4ec7a8 in archive_read_open1 libarchive/archive_read.c:530
    #6 0x4eb06b in LLVMFuzzerTestOneInput ibarchive_fuzzer.cc:44:3

```
