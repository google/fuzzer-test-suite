Finds [CVE-2015-8317](https://access.redhat.com/security/cve/cve-2015-8317),
1-byte-read-heap-buffer-overflow in [libxml2](http://xmlsoft.org/).

Time to find: < 1 minute.
```
==26806==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x62100161f900
READ of size 1 at 0x62100161f900 thread T0
    #0 0x55d208 in xmlParseXMLDecl parser.c:10666:2
    #1 0x55eaa7 in xmlParseDocument parser.c:10771:2
    #2 0x57cb18 in xmlDoRead parser.c:15298:5
```


