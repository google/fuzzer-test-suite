Fuzzing benchmark for [OpenThread](https://github.com/openthread/openthread).

Two fuzz targets are included: `ip6_send_fuzzer` and
`radio_receive_done_fuzzer`.

Reproducers for 12 historical OpenThread bugs are provided.  To reproduce the
crashes or find them by fuzzing, make sure you build the appropriate revision of
OpenThread.  For example, to reproduce the first crash below, we would do the
following:
```shell
$ REVISION=94436b6f5f882f918e97ac74fb9a041375ab86b7 ${FTS}/openthread-2018-02-27/build.sh
$ ./openthread-2018-02-27-fsanitize_fuzzer-radio ${FTS}/openthread-2018-02-27/repro1
```

Bug | Fuzzer | Revision | Reproducer Input
--- | ------ | -------- | ----------------
[heap-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=2757&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | radio | 94436b6f5f882f918e97ac74fb9a041375ab86b7 | repro1
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=2855&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | radio | 49c80937be5de63c1c7b7652eacb22e1adc459b6 | repro2
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=3252&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | radio | 71d40a5c838d345248fbc130c74182dda99d85f1 | repro3
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=3256&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | radio | 71d40a5c838d345248fbc130c74182dda99d85f1 | repro4
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=3285&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | ab4073980f120bbd4eb9f6d58950f2f03f88dac3 | repro5
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=3322&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | ab4073980f120bbd4eb9f6d58950f2f03f88dac3 | repro6
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=4637&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | radio | 7b706a9aa673042fa4586e19ab72c52769b493af | repro7
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=5864&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | 68a605f22e579ae45ab1d8221faa2d45e8668e05 | repro8
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=5874&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | 68a605f22e579ae45ab1d8221faa2d45e8668e05 | repro9
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=5935&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | 68a605f22e579ae45ab1d8221faa2d45e8668e05 | repro10
[stack-buffer-overflow](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=7766&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | bf52ed706facbbbd12b2d86c902c0f71b2b72bb0 | repro11
[null-dereference](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=8230&can=1&q=label%3AProj-openthread&colspec=ID%20Type%20Component%20Status%20Proj%20Reported%20Owner%20Summary) | ip6 | 585080e3a0a1ee4287b9cb5745e470e6ac4c5c7b | repro12
