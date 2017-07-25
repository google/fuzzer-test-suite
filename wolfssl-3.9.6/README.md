Finds a SEGV and three heap overflow errors in `src/ssl.c`
in [wolfSSL v.3.9.6](https://www.wolfssl.com/wolfSSL/Home.html).

All times reported correspond to a starting corpus containing only seed.pem

## crash-dde9..
Time to find: < 2 seconds.
```
==108387==ERROR: AddressSanitizer: SEGV on unknown address 0x000000000000 (pc 0x7f1162e8d9e8 bp 0x7ffe3e32d2a0 sp 0x7ffe3e32cce0 T0)
==108387==The signal is caused by a READ memory access.
==108387==Hint: address points to the zero page.
    #0 0x7f1162e8d9e7 in wolfSSL_CertManagerVerifyBuffer src/ssl.c:4364
    #1 0x7f1162e8d9e7 in ?? ??:0
    #2 0x510014 in verify_cert_mem(unsigned char const*, unsigned int, unsigned char const*, unsigned int) target.cc:86

AddressSanitizer can not provide additional info.
SUMMARY: AddressSanitizer: SEGV (lib/libwolfssl.so.3+0x11d9e7)
==108387==ABORTING
```

#####Analysis
Inside wolfSSL_CertManagerVerifyBuffer (src/ssl.c), a PEM certificate is decoded
to a DER certificate:
```
    if (format == SSL_FILETYPE_PEM) {
        int eccKey = 0; /* not used */
    #ifdef WOLFSSL_SMALL_STACK
        EncryptedInfo* info = NULL;
    #else
        EncryptedInfo  info[1];
    #endif

    #ifdef WOLFSSL_SMALL_STACK
        info = (EncryptedInfo*)XMALLOC(sizeof(EncryptedInfo), cm->heap,
                                       DYNAMIC_TYPE_TMP_BUFFER);
        if (info == NULL) {
            XFREE(cert, cm->heap, DYNAMIC_TYPE_TMP_BUFFER);
            return MEMORY_E;
        }
    #endif

        info->set      = 0;
        info->ctx      = NULL;
        info->consumed = 0;

        ret = PemToDer(buff, sz, CERT_TYPE, &der, cm->heap, info, &eccKey);
        InitDecodedCert(cert, der->buffer, der->length, cm->heap);

    #ifdef WOLFSSL_SMALL_STACK
        XFREE(info, cm->heap, DYNAMIC_TYPE_TMP_BUFFER);
    #endif
    }
    else
        InitDecodedCert(cert, (byte*)buff, (word32)sz, cm->heap);

    if (ret == 0)
        ret = ParseCertRelative(cert, CERT_TYPE, 1, cm);

#ifdef HAVE_CRL
    if (ret == 0 && cm->crlEnabled)
        ret = CheckCertCRL(cm->crl, cert);
#endif

    FreeDecodedCert(cert);
    FreeDer(&der);

```
However, in the lines
```
ret = PemToDer(buff, sz, CERT_TYPE, &der, cm->heap, info, &eccKey);
InitDecodedCert(cert, der->buffer, der->length, cm->heap);
```
the return value of PemToDer function is not checked. This results in a
segmentation fault in case of a malformed certificate that causes an invalid
derefernce for `der->buffer` and `der->length`

## crash-78fbd..

Time to find: < 5 seconds.

```
==112075==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x61a0000005a6 at pc 0x7fc7284b6f12 bp 0x7ffc2291f0e0 sp 0x7ffc2291f0d8
READ of size 1 at 0x61a0000005a6 thread T0
    #0 0x7fc7284b6f11 in PemToDer src/ssl.c:3540
    #1 0x7fc7284b6f11 in ?? ??:0
    #2 0x7fc7284ba9b8 in wolfSSL_CertManagerVerifyBuffer src/ssl.c:4363
    #3 0x7fc7284ba9b8 in ?? ??:0
    #4 0x510014 in verify_cert_mem(unsigned char const*, unsigned int, unsigned char const*, unsigned int) target.cc:86
```

#####Analysis
In PemToDer (src/ssl.c), since no check is performed on the exact distance of
consumedEnd from bufferEnd, an out-of-bounds read can occur at the end of the
footer in the certificate.

```
if (consumedEnd < bufferEnd) {  /* handle no end of line on last line */
    /* eat end of line */
    if (consumedEnd[0] == '\n')
        consumedEnd++;
    else if (consumedEnd[1] == '\n')
        consumedEnd += 2;
    else {
        if (info)
            info->consumed = (long)(consumedEnd+2 - (char*)buff);
        return SSL_BAD_FILE;
    }
}

if (info)
    info->consumed = (long)(consumedEnd - (char*)buff);

/* set up der buffer */
neededSz = (long)(footerEnd - headerEnd);
if (neededSz > sz || neededSz < 0)
    return SSL_BAD_FILE;

ret = AllocDer(pDer, (word32)neededSz, type, heap);
if (ret < 0) {
    return ret;
}
der = *pDer;

...
```

## crash-8574..,  crash-a43c..,  crash-b2f..
Time to find: 30 seconds to 1 minute

```
==117799==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60300000002b at pc 0x7f1996015b11 bp 0x7ffcdf5ae350 sp 0x7ffcdf5ae348
READ of size 1 at 0x60300000002b thread T0
    #0 0x7f1996015b10 in PemToDer src/ssl.c:3463
    #1 0x7f1996015b10 in ?? ??:0
    #2 0x7f1996019a98 in wolfSSL_CertManagerVerifyBuffer src/ssl.c:4368
    #3 0x7f1996019a98 in ?? ??:0
    #4 0x510014 in verify_cert_mem(unsigned char const*, unsigned int, unsigned char const*, unsigned int) target.cc:86
```

In PemToDer (src/ssl.c), in the case of invalid headers, no check is performed
on the lengths. This results in an out-of-bounds read of heap buffer, when the
end of line in the certificate header is consumed past the allocated buffer
`buff`.

```
...
    headerEnd = XSTRNSTR((char*)buff, header, sz);
...
    headerEnd += XSTRLEN(header);
...
    /* eat end of line */
    if (headerEnd[0] == '\n')
        headerEnd++;
    else if (headerEnd[1] == '\n')
        headerEnd += 2;
    else {
        if (info)
            info->consumed = (long)(headerEnd+2 - (char*)buff);
        return SSL_BAD_FILE;
    }
...
```

#### crash-1f39
Time to find: 2 to 5 minutes.

```
==126822==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x603000000120 at pc 0x7fa2e327074c bp 0x7ffe711bda30 sp 0x7ffe711bda28
READ of size 1 at 0x603000000120 thread T0
    #0 0x7fa2e327074b in GetSequence wolfcrypt/src/asn.c:555
    #1 0x7fa2e327074b in GetCertHeader wolfcrypt/src/asn.c:2244
    #2 0x7fa2e327074b in DecodeToKey wolfcrypt/src/asn.c:3178
    #3 0x7fa2e327074b in ?? ??:0
    #4 0x7fa2e327b6e3 in ParseCertRelative wolfcrypt/src/asn.c:4987
    #5 0x7fa2e327b6e3 in ?? ??:0
    #6 0x7fa2e332ee37 in wolfSSL_CertManagerVerifyBuffer src/ssl.c:4388
    #7 0x7fa2e332ee37 in ?? ??:0
    #8 0x510014 in verify_cert_mem(unsigned char const*, unsigned int, unsigned char const*, unsigned int) target.cc:86
```

#####Analysis
In PemToDer (src/ssl.c), in the case of a malformed certificate, the der buffer
might be having a size of 0 but the no SSL_BAD_FILE error is returned.
```
    /* set up der buffer */
    neededSz = (long)(footerEnd - headerEnd);
    if (neededSz > sz || neededSz < 0)
        return SSL_BAD_FILE;
```
