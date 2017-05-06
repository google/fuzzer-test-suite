Finds [oss-fuzz/370](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=370),
a crash in [LLVM](http://llvm.org) C++ demanger.
The crash is caused by a pop-back from an empty std::vector object
and manifests in different ways (NULL deref, stack overflow, run-time error
message, etc) depending on the standard C++ library implementation used.
Fixed [here](http://llvm.org/viewvc/llvm-project?view=revision&revision=293330).

Also finds
[oss-fuzz/582](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=582),
out-of-range access in std::string.
```
terminate called after throwing an instance of 'std::out_of_range'
  what():  basic_string::replace
```

This first bug took OSS-Fuzz several weeks to discover, the second took several
months. Both reproducers attached.
