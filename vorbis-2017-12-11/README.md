Fuzzing benchmark for [Vorbis](https://github.com/xiph/vorbis).
Contains CVE-2018-5146 (pwn2own 2018), a buffer overflow. Reproducer provided.
As of 2018-04 libFuzzer finds this bug in several hundred CPU hours
(a bit faster with `-use_value_profile=1`)

```
==108564==ERROR: AddressSanitizer: heap-buffer-overflow on ...
READ of size 4 at 0x619000000480 thread T0
    #0 0x56b301 in vorbis_book_decodevv_add lib/codebook.c:479:24
    #1 0x5ae876 in res2_inverse lib/res0.c:843:18
    #2 0x5b4031 in mapping0_inverse lib/mapping0.c:748:5
    #3 0x528b57 in _fetch_and_process_packet lib/vorbisfile.c:705:15
    #4 0x52aa17 in ov_read_filter lib/vorbisfile.c:1976:15
    #5 0x52b715 in ov_read lib/vorbisfile.c:2096:10
    #6 0x4fab0d in LLVMFuzzerTestOneInput
```

See also:
* http://blogs.360.cn/blog/how-to-kill-a-firefox-en/
* https://www.thezdi.com/blog/2018/4/5/quickly-pwned-quickly-patched-details-of-the-mozilla-pwn2own-exploit
