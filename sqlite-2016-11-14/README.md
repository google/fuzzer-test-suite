Finds two heap-buffer-overflows in
[SQLite](https://www.sqlite.org):
[1](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=199),
[2](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=171), 
and a [memory leak](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=397). 

Both buffer overflows require lots of CPU time to find (with libFuzzer, at the time of
writing), the leak is more shallow.
