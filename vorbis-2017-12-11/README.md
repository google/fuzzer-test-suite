Fuzzing benchmark for [Vorbis](https://github.com/xiph/vorbis).
Contains CVE-2018-5146 (pwn2own 2018), a buffer overflow. Reproducer provided
(`crash-e86e0482b8d66f924e50e62f5d7cc36a0acb03a7`).
As of 2018-04 libFuzzer finds this bug in several hundred CPU hours
(a bit faster with `-use_value_profile=1`).

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

A second buffer overflow is also present and is found by libFuzzer after several
hundred CPU hours.  Reproducer provided
(`crash-8c5dea6410b0fb0b21ff968a9966a0bd7956405f`).  This bug no longer
reproduces after the [fix for CVE-2018-5146](
https://github.com/xiph/vorbis/commit/667ceb4aab60c1f74060143bb24e5f427b3cce5f).

```
==848==ERROR: AddressSanitizer: heap-buffer-overflow on ...
READ of size 16 at 0x61d000006280 thread T0
    #0 0x5bb227 in vorbis_book_decodev_add lib/codebook.c:407:17
    #1 0x5f0dc9 in _01inverse lib/res0.c:693:20
    #2 0x5f45c9 in res1_inverse lib/res0.c:757:12
    #3 0x5fbc1b in mapping0_inverse lib/mapping0.c:748:5
    #4 0x57f8aa in _fetch_and_process_packet lib/vorbisfile.c:705:15
    #5 0x581594 in ov_read_filter lib/vorbisfile.c:1976:15
    #6 0x5822a4 in ov_read lib/vorbisfile.c:2096:10
    #7 0x577c4a in LLVMFuzzerTestOneInput
```

Also contains a null-dereference, which libFuzzer found after several hundred
CPU hours with `-use_value_profile=1`.  Reproducer provided
(`crash-23c2d78e497bf4aebe5859e3092657cb0af4c299`).  This bug also no longer
reproduces after the [fix for CVE-2018-5146](
https://github.com/xiph/vorbis/commit/667ceb4aab60c1f74060143bb24e5f427b3cce5f).
```
==18193==ERROR: AddressSanitizer: SEGV on unknown address 0x000000000000 ...
==18193==The signal is caused by a READ memory access.
==18193==Hint: address points to the zero page.
    #0 0x5f0ccf in _01inverse lib/res0.c:690:35
    #1 0x5f45c9 in res1_inverse lib/res0.c:757:12
    #2 0x5fbc1b in mapping0_inverse lib/mapping0.c:748:5
    #3 0x57f8aa in _fetch_and_process_packet lib/vorbisfile.c:705:15
    #4 0x581594 in ov_read_filter lib/vorbisfile.c:1976:15
    #5 0x5822a4 in ov_read lib/vorbisfile.c:2096:10
    #6 0x577c4a in LLVMFuzzerTestOneInput
```

See also:
* http://blogs.360.cn/blog/how-to-kill-a-firefox-en/
* https://www.thezdi.com/blog/2018/4/5/quickly-pwned-quickly-patched-details-of-the-mozilla-pwn2own-exploit
