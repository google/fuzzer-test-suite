Find [oss-fuzz/370](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=370)
a crash in [LLVM](https://llvm.org) C++ demanger.
The crash is caused by a pop-back from an empty std::vector object
and manifests in different ways (NULL deref, stack overflow, run-time error
message, etc) depending on the standard C++ library implementation used.
Reproducer attached. This bug took OSS-Fuzz several weeks to discover.

