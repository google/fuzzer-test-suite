Bechmark for [libpng](http://www.libpng.org/pub/png/libpng.html)-1.2.56.

This code may call `malloc(2147483648)` (repro attached).

We use this benchmark to verify that the fuzzer can reach a set of known source
locations.
