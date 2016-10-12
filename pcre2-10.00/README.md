Finds several bugs in [PCRE2](http://www.pcre.org/) version 10.00 (Jan 2015).

Time to find: < 1 minute.

```
==28520==ERROR: AddressSanitizer: heap-buffer-overflow
READ of size 1 at 0x6040000a2a4f thread T0
    #0 0x585630 in match src/pcre2_match.c:5968:11
    #1 0x5496d1 in pcre2_match_8 src/pcre2_match.c:6876:8
    #2 0x59b498 in regexec src/pcre2posix.c:291:6
    #3 0x4f0359 in LLVMFuzzerTestOneInput

==28522==ERROR: AddressSanitizer: heap-use-after-free
READ of size 1 at 0x61100009144b thread T0
    #0 0x58550a in match src/pcre2_match.c:1426:16
    #1 0x574752 in match src/pcre2_match.c:5145:11
    #2 0x573efc in match src/pcre2_match.c:3607:11
    #3 0x5496d1 in pcre2_match_8 src/pcre2_match.c:6876:8
    #4 0x59b498 in regexec src/pcre2posix.c:291:6
    #5 0x4f0359 in LLVMFuzzerTestOneInput
```
