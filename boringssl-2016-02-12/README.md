Find a [8-byte-read-heap-use-after-free bug](https://bugs.chromium.org/p/chromium/issues/detail?id=586798)
in [Boringssl](https://boringssl.googlesource.com/boringssl/), reproducer
provided.

Time to find: 1 hour or more.
```
==4514==ERROR: AddressSanitizer: heap-use-after-free
READ of size 8 at 0x6030000002b8 thread T0
    #0 0x5a4501 in ASN1_STRING_free crypto/asn1/asn1_lib.c:459:12
    #1 0x5b32dd in ASN1_primitive_free crypto/asn1/tasn_fre.c:241:9
    #2 0x5b31e7 in ASN1_primitive_free crypto/asn1/tasn_fre.c:236:9
    #3 0x5b21e4 in ASN1_item_free crypto/asn1/tasn_fre.c:69:5
    #4 0x515b59 in sk_pop_free crypto/stack/stack.c:142:7
    #5 0x4f81b9 in dsa_priv_decode crypto/evp/p_dsa_asn1.c:288:3
    #6 0x50a5ed in EVP_PKCS82PKEY crypto/pkcs8/pkcs8.c:616:10
    #7 0x4f3f0b in d2i_AutoPrivateKey crypto/evp/evp_asn1.c:151:11
    #8 0x4f0624 in LLVMFuzzerTestOneInput
```
