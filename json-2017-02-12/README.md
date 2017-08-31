This benchmark finds an [assertion failure](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=641) in [json](https://github.com/nlohmann/json).

As of August 31, 2017, it's usually found in about 5 minutes using the provided
seed.

```
json-2017-02-12-libfuzzer: BUILD/test/src/fuzzer-parse_json.cpp:50: int LLVMFuzzerTestOneInput(const uint8_t *, size_t): Assertion `s1 == s2' failed.
==...== ERROR: libFuzzer: deadly signal
```
