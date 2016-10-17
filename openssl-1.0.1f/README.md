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


Note: the build may sometimes fail, apparently due to a race in the makefiles. If so, just rebuild from scratch.
