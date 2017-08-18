This is a fuzzing benchmark for [proj.4](https://github.com/OSGeo/proj.4).

This benchmark finds a direct and an indirect leak as follows:

```
==17769==ERROR: LeakSanitizer: detected memory leaks

Direct leak of 640 byte(s) in 1 object(s) allocated from:
    #0 0x4c386c in __interceptor_malloc llvm.src/projects/compiler-rt/lib/asan/asan_malloc_linux.cc:66:3
    #1 0x4fa32e in pj_malloc src/pj_malloc.c:57:21
    #2 0x4fa32e in pj_calloc src/pj_malloc.c:80
    #3 0x5ab711 in pj_urm5 src/PJ_urm5.c:39:5
    #4 0x4f55d3 in pj_init_ctx src/pj_init.c:502:17
    #5 0x4f4a7f in pj_init_plus_ctx src/pj_init.c:409:14
    #6 0x4f37cf in LLVMFuzzerTestOneInput test/fuzzers/standard_fuzzer.cpp:89:21

Indirect leak of 32 byte(s) in 1 object(s) allocated from:
    #0 0x4c386c in __interceptor_malloc llvm.src/projects/compiler-rt/lib/asan/asan_malloc_linux.cc:66:3
    #1 0x4fa32e in pj_malloc src/pj_malloc.c:57:21
    #2 0x4fa32e in pj_callocsrc/pj_malloc.c:80
    #3 0x5ab7e0 in pj_projection_specific_setup_urm5 src/PJ_urm5.c:41:27
    #4 0x4f7579 in pj_init_ctx src/pj_init.c:726:21
    #5 0x4f4a7f in pj_init_plus_ctx src/pj_init.c:409:14
    #6 0x4f37cf in LLVMFuzzerTestOneInput test/fuzzers/standard_fuzzer.cpp:89:21

SUMMARY: AddressSanitizer: 672 byte(s) leaked in 2 allocation(s).

```

These leaks are intertwined, and can be found with the same single reproducer, which is included in this directory.

As of August 18, 2017, this benchmark generally takes anywhere between 2 and 10 minutes to complete 
when using libFuzzer and the provided seed.

