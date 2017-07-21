Finds a SEGV error during parsing of a corrupted certificate, in
[GnuTLS](https://www.gnutls.org/) v.3.5.0. Fixed in [da4c7a39](https://gitlab.com/gnutls/gnutls/commit/da4c7a393d273076af4f650f6cb1fd6329078824).

POC
===
```
../BUILD/bin/certtool --verify-chain --load-ca-certificate ca_chain.pem --infile full_pem_chain.pem
```

(To attempt replication with the respective libFuzzer driver, run with
`ASAN_OPTIONS=detect_leaks=0` and a starting corpus of certificates in PEM
format).

Root Cause Analysis
===================

A corrupted certificate may cause a Segmentation Fault in certtool.
The cause is a missing check for `p->oid` to be not NULL inside
`gnutls_oid_to_ecc_curve`:

```
/**
 * gnutls_oid_to_ecc_curve:
 * @oid: is a curve's OID
 *
 * Returns: return a #gnutls_ecc_curve_t value corresponding to
 *   the specified OID, or %GNUTLS_ECC_CURVE_INVALID on error.
 *
 * Since: 3.4.3
 **/
gnutls_ecc_curve_t gnutls_oid_to_ecc_curve(const char *oid)
{
    gnutls_ecc_curve_t ret = GNUTLS_ECC_CURVE_INVALID;

    GNUTLS_ECC_CURVE_LOOP(
        if (strcasecmp(p->oid, oid) == 0 && _gnutls_pk_curve_exists(p->id)) {
            ret = p->id;
            break;
        }
    );

    return ret;
}
```
