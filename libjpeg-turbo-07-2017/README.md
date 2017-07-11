This is a fuzzing benchmark for [libjpeg-turbo](https://github.com/libjpeg-turbo/libjpeg-turbo).
Instead of searching for a bug, this benchmark attempts to reach a particular line of code which is known to be difficult to reach.

As of July 11, 2017, this benchmark can be completed in about an hour when using libFuzzer and the provided seed. 

