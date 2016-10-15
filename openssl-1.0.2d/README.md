Finds
[CVE-2015-3193](https://blog.fuzzing-project.org/31-Fuzzing-Math-miscalculations-in-OpenSSLs-BN_mod_exp-CVE-2015-3193.html),
a miscalculation in [OpenSSL](https://www.openssl.org/)'s BN_mod_exp.

Time to find: < 1 minute. Crash reproducer included.
```
Assertion `strcmp(openssl_results.exptmod, gcrypt_results.exptmod)==0' failed.
```


