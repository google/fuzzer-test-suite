This is a coverage benchmark for [freetype2](https://freetype.org/freetype2/docs/index.html).
Instead of searching for a bug, this benchmark attempts to reach a particular line of code which is known to be difficult to reach.

As of September 6, 2017, this benchmark takes about 5 minutes using the provided seeds.

This version of freetype also contains an [integer overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=2027), and it takes a long time to find by fuzzing.
