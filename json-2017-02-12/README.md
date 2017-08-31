This benchmark finds an [assertion failure](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=641) in [json](https://github.com/nlohmann/json).

It's usually found in about 5 minutes using the provided seed.

```
json-2017-02-12-libfuzzer: BUILD/test/src/fuzzer-parse_json.cpp:50: int LLVMFuzzerTestOneInput(const uint8_t *, size_t): Assertion `s1 == s2' failed.
==3260== ERROR: libFuzzer: deadly signal
    #0 0x4eafb3  (json-2017-02-12-libfuzzer+0x4eafb3)
    #1 0x53d291  (json-2017-02-12-libfuzzer+0x53d291)
    #2 0x53d25d  (json-2017-02-12-libfuzzer+0x53d25d)
    ... (/lib/x86_64-linux-gnu/libpthread.so.0)
    ... (/lib/x86_64-linux-gnu/libc.so.6)
    ... (/lib/x86_64-linux-gnu/*)
    #8 0x519a34  (json-2017-02-12-libfuzzer+0x519a34)
    #9 0x53e50d  (json-2017-02-12-libfuzzer+0x53e50d)
    #10 0x53dd28  (json-2017-02-12-libfuzzer+0x53dd28)
    #11 0x53dbf8  (json-2017-02-12-libfuzzer+0x53dbf8)
    #12 0x53f72e  (json-2017-02-12-libfuzzer+0x53f72e)
    #13 0x537508  (json-2017-02-12-libfuzzer+0x537508)
    #14 0x5329f0  (json-2017-02-12-libfuzzer+0x5329f0)
    ... (/lib/x86_64-linux-gnu/*)
    #16 0x41cfc8  (json-2017-02-12-libfuzzer+0x41cfc8)
```
