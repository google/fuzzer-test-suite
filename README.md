# fuzzer-test-suite

This is a set of tests (benchmarks) for fuzzing engines (fuzzers).

The goal of this project is to have a set of fuzzing benchmarks derived from real-life
libraries that have interesting bugs, hard-to-find code paths, or other
challenges for bug finding tools.

The current version supports [libFuzzer](http://libFuzzer.info),
in future versions we exect to support [AFL](http://lcamtuf.coredump.cx/afl/)
and potentially other fuzzing engines.

# See also

* [AddressSanitizer](http://clang.llvm.org/docs/AddressSanitizer.html)

# Contributing
See [CONTRIBUTING](CONTRIBUTING) first. 
If you want to add one more benchmark to the test suite,
simply mimic one of the existing benchmarks and send the pull request. 

# Disclaimer
This is not an official Google product.
