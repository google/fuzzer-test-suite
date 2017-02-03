Finds
[CVE-2017-3732](https://www.openssl.org/news/secadv/20170126.txt),
a carry propagating bug in [OpenSSL](https://www.openssl.org/)'s `BN_mod_exp`.
This was originally
[discovered](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=407)
by [OSS-Fuzz](https://github.com/google/oss-fuzz)
using the in-tree
[bignum fuzz target](https://github.com/openssl/openssl/blob/OpenSSL_1_1_0-stable/fuzz/bignum.c).
Fixed in openssl
[here](https://github.com/openssl/openssl/commit/3f4bcf5bb664b47ed369a70b99fac4e0ad141bb3)
and in boringssl
[here](https://github.com/google/boringssl/commit/d103616db14ca9587f074efaf9f09a48b8ca80cb).

This is similar to
[CVE-2015-3193](https://blog.fuzzing-project.org/31-Fuzzing-Math-miscalculations-in-OpenSSLs-BN_mod_exp-CVE-2015-3193.html)
but is a different bug.

It took at least one CPU year to find this bug for the first time.
Reproducer provided in this directory.

```
bignum.c:91: OpenSSL internal error: assertion failed: success
```
