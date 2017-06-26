This is a benchmark for finding a
[heap-buffer-overflow bug](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=925) in
[Little-CMS](https://github.com/mm2/Little-CMS).

Note that, in OSS-Fuzz, this bug was first found with [AFL](http://lcamtuf.coredump.cx/afl/).

The following error can be found within 30 minutes of fuzzing, from the provided seed.

```
==27232==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60800011b68c at pc 0x00000057c11a bp 0x7ffd7544b130 sp 0x7ffd7544b128
READ of size 4 at 0x60800011b68c thread T0
    #0 0x57c119 in TetrahedralInterpFloat BUILD/src/cmsintrp.c:642:22
    #1 0x599c56 in _LUTeval16 BUILD/src/cmslut.c:1330:14
    #2 0x51a13a in CachedXFORM BUILD/src/cmsxform.c:525:17
    #3 0x512b8d in cmsDoTransform BUILD/src/cmsxform.c:189:5
    #4 0x4ea37c in LLVMFuzzerTestOneInput cms_transform_fuzzer.c
```

Generally, the above error is found. However, the [following error](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=931) is also present.

```
==96256==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60800000048c at pc 0x00000057bfea bp 0x7ffd1790c010 sp 0x7ffd1790c008
READ of size 4 at 0x60800000048c thread T0
    #0 0x57bfe9 in TetrahedralInterpFloat BUILD/src/cmsintrp.c:642:22
    #1 0x59a1f1 in _LUTevalFloat /usr/local BUILD/src/cmslut.c:1356:15
    #2 0x54e591 in XFormSampler16 BUILD/src/cmsopt.c:423:5
    #3 0x593e77 in cmsStageSampleCLut16bit BUILD/src/cmslut.c:797:14
    #4 0x54cdbf in OptimizeByResampling BUILD/src/cmsopt.c:734:10
    #5 0x54a74f in _cmsOptimizePipeline BUILD/src/cmsopt.c:1942:17
    #6 0x51521f in AllocEmptyTransform BUILD/src/cmsxform.c:819:15
    #7 0x5140a0 in cmsCreateExtendedTransform BUILD/src/cmsxform.c:1075:13
    #8 0x516ce2 in cmsCreateMultiprofileTransformTHR BUILD/src/cmsxform.c:1175:12
    #9 0x516ce2 in cmsCreateTransformTHR BUILD/src/cmsxform.c:1216
    #10 0x516ce2 in cmsCreateTransform BUILD/src/cmsxform.c:1226
    #11 0x4ea02c in LLVMFuzzerTestOneInput cms_transform_fuzzer.c:31:30
```
