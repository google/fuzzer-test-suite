Finds a SEGV and three heap overflow errors in `src/ssl.c`
in [wolfSSL v.3.9.6](https://www.wolfssl.com/wolfSSL/Home.html).

Crash reproducers included. You may reproduce the crashes by running the individual
driver on each case:
```
./driver crash-b2f60a22d5e8e98e31f8bea2a1f5ec8c66babea8 certs/ca.pem
```

Root Cause Analyses
===================

#### crash-dde9..
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

#### crash-78fbd..

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

#### crash-8574..,  crash-a43c..,  crash-b2f..
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
In PemToDer (src/ssl.c), in the case of a malformed certificate, the der buffer
might be having a size of 0 but the no SSL_BAD_FILE error is returned.
```
    /* set up der buffer */
    neededSz = (long)(footerEnd - headerEnd);
    if (neededSz > sz || neededSz < 0)
        return SSL_BAD_FILE;
```
