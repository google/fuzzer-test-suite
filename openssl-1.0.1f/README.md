Finds [HeartBleed (CVE-2014-0160)](https://en.wikipedia.org/wiki/Heartbleed),
multi-byte-read-heap-buffer-overflow in [openssl](https://www.openssl.org/).

Time to find: < 10 seconds.
```
=20302==ERROR: AddressSanitizer: heap-buffer-overflow
READ of size 53713 at 0x629000009748 thread T0
    #0 0x4a97b6 in __asan_memcpy
    #1 0x4fd102 in tls1_process_heartbeat ssl/t1_lib.c:2586:3
    #2 0x57cca2 in ssl3_read_bytes ssl/s3_pkt.c:1092:4
    #3 0x581c7d in ssl3_get_message ssl/s3_both.c:457:7
    #4 0x545184 in ssl3_get_client_hello ssl/s3_srvr.c:941:4
    #5 0x5411de in ssl3_accept ssl/s3_srvr.c:357:9
```

Also finds a memory leak, [CVE-2014-3513](https://www.openssl.org/news/secadv/20141015.txt), repro attached:
```
Direct leak of 32 byte(s) in 1 object(s) allocated from:
    #0 0x514f18 in __interceptor_malloc
    #1 0x5fd25b in CRYPTO_malloc crypto/mem.c:308:8
    #2 0x6539c1 in sk_new crypto/stack/stack.c:125:11
    #3 0x6539c1 in sk_new_null crypto/stack/stack.c:117
    #4 0x564bf3 in ssl_parse_clienthello_use_srtp_ext ssl/d1_srtp.c:345:7
    #5 0x55574a in ssl_parse_clienthello_tlsext ssl/t1_lib.c:1419:7
    #6 0x5997c2 in ssl3_get_client_hello ssl/s3_srvr.c:1180:8
    #7 0x594a36 in ssl3_accept ssl/s3_srvr.c:357:9
```
