Finds [CVE-2015-8317](https://access.redhat.com/security/cve/cve-2015-8317),
1-byte-read-heap-buffer-overflow and a memory leak in [libxml2](http://xmlsoft.org/).

Time to find: < 1 minute, reproducer provided.
```
==26806==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x62100161f900
READ of size 1 at 0x62100161f900 thread T0
    #0 0x55d208 in xmlParseXMLDecl parser.c:10666:2
    #1 0x55eaa7 in xmlParseDocument parser.c:10771:2
    #2 0x57cb18 in xmlDoRead parser.c:15298:5
```

Time to find: probably > 1 hour (the above shallow bug hides this one), reproducer provided.

```
Indirect leak of 48 byte(s) in 1 object(s) allocated from:
    #0 0x4c250c in __interceptor_malloc
    #1 0x5ef0fd in xmlNewDocElementContent valid.c:952:34
    #2 0x532c2b in xmlParseElementMixedContentDecl parser.c:6200:16
    #3 0x5367cd in xmlParseElementContentDecl parser.c:6624:16
    #4 0x537843 in xmlParseElementDecl parser.c:6691:12
    #5 0x538b84 in xmlParseMarkupDecl parser.c:6934:4
    #6 0x562fd7 in xmlParseInternalSubset parser.c:8401:6
    #7 0x56166e in xmlParseDocument parser.c:10809:6
    #8 0x57fe49 in xmlDoRead parser.c:15298:5
    #9 0x4f0f87 in LLVMFuzzerTestOneInput
```

Also finds [bug 756528](https://bugzilla.gnome.org/show_bug.cgi?id=756528)
(fixed
[here](https://git.gnome.org/browse/libxml2/commit/?id=6360a31a84efe69d155ed96306b9a931a40beab9)):

```
ERROR: AddressSanitizer: heap-buffer-overflow ...
READ of size 1 at 0x61900000007b thread T0
    #0 0x7712a5 in xmlDictComputeFastQKey dict.c:489:18
    #1 0x76f037 in xmlDictQLookup dict.c:1093:12
    #2 0x77bab5 in xmlSAX2StartElementNs SAX2.c:2238:17
    #3 0x543e73 in xmlParseStartTag2 parser.c:9707:6
    #4 0x53aecb in xmlParseElement parser.c:10069:16
```
