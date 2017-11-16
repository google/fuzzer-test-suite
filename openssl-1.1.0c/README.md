
## bignum
### CVE-2017-3732
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
Reproducer provided in this directory (`crash-ab3eea077a07a1353f86eea4b6075df2e6319a75`).

```
bignum.c:91: OpenSSL internal error: assertion failed: success
```

### CVE-2017-3736

A very similar bug was found later:
[bn_sqrx8x_internal carry bug on x86_64 (CVE-2017-3736)](https://www.openssl.org/news/secadv/20171102.txt). 
It was a bug in assembly implementation targeted at processors with the BMI1, BMI2 and ADX extensions.
It won't reproduce on other hardware. See also:
[fix](https://github.com/openssl/openssl/commit/668a709a8d7ea374ee72ad2d43ac72ec60a80eee),
[regression test](https://github.com/openssl/openssl/commit/420b88cec8c6f7c67fad07bf508dcccab094f134),
[original report](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=2905).
On proper CPU libFuzzer finds this bug in < 1 day. 

## x509

Finds [CVE-2017-3735](https://www.openssl.org/news/secadv/20170828.txt), a heap buffer overflow in `X509v3_addr_get_afi`.
It took OSS-Fuzz ~9 months (and ~5 CPU years) to discover this bug initially.
Reproducer provided in this directory (`crash-4fce1eeb339d851b72fedba895163ec1daab51f3`).

```
==5860==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x602000000631 at pc 0x0000005217ee bp 0x7ffe60472ac0 sp 0x7ffe60472ab8
READ of size 1 at 0x602000000631 thread T0
    #0 0x5217ed in X509v3_addr_get_afi crypto/x509v3/v3_addr.c:89:52
    #1 0x5217ed in i2r_IPAddrBlocks crypto/x509v3/v3_addr.c:203
    #2 0x535b42 in X509V3_EXT_print crypto/x509v3/v3_prn.c:123:14
    #3 0x535f31 in X509V3_extensions_print crypto/x509v3/v3_prn.c:163:14
    #4 0x509e70 in X509_print_ex crypto/x509/t_x509.c:190:9
    #5 0x4ec889 in LLVMFuzzerTestOneInput fuzz/x509.c:27:9

0x602000000631 is located 0 bytes to the right of 1-byte region [0x602000000630,0x602000000631)
allocated by thread T0 here:
    #0 0x4bf71c in __interceptor_malloc
    #1 0x55d2e7 in ASN1_STRING_set crypto/asn1/asn1_lib.c:277:21
    #2 0x564da9 in asn1_ex_c2i crypto/asn1/tasn_dec.c:869:18
    #3 0x564da9 in asn1_d2i_ex_primitive crypto/asn1/tasn_dec.c:743
    #4 0x5624ec in asn1_item_embed_d2i crypto/asn1/tasn_dec.c
    #5 0x566396 in asn1_template_noexp_d2i crypto/asn1/tasn_dec.c:606:15
    #6 0x563148 in asn1_template_ex_d2i crypto/asn1/tasn_dec.c:482:16
    #7 0x562042 in asn1_item_embed_d2i crypto/asn1/tasn_dec.c:347:19
    #8 0x566848 in asn1_template_noexp_d2i crypto/asn1/tasn_dec.c:575:18
    #9 0x563148 in asn1_template_ex_d2i crypto/asn1/tasn_dec.c:482:16
    #10 0x5615c1 in asn1_item_embed_d2i crypto/asn1/tasn_dec.c:162:20
    #11 0x561154 in ASN1_item_ex_d2i crypto/asn1/tasn_dec.c:114:10
    #12 0x561154 in ASN1_item_d2i crypto/asn1/tasn_dec.c:104
    #13 0x535898 in X509V3_EXT_print crypto/x509v3/v3_prn.c:88:19
    #14 0x535f31 in X509V3_extensions_print crypto/x509v3/v3_prn.c:163:14
    #15 0x509e70 in X509_print_ex crypto/x509/t_x509.c:190:9
    #16 0x4ec889 in LLVMFuzzerTestOneInput fuzz/x509.c:27:9
```
