Finds two heap-buffer-overflows in
[SQLite](https://www.sqlite.org):
[1](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=199),
[2](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=171)

Both bugs require lots of CPU time to find (with libFuzzer, at the time of
writing).
