Fuzzing benchmark for [wpantund](https://github.com/openthread/wpantund).
On OSS-Fuzz, this fuzzer found a null dereference.  In local experiments, the
dereference hasn't been found yet.

```
==17==ERROR: AddressSanitizer: SEGV on unknown address 0x000000000000 (pc 0x00000065da2c bp 0x7fff03ddf870 sp 0x7fff03ddf630 T0)
==17==The signal is caused by a READ memory access.
==17==Hint: address points to the zero page.
SCARINESS: 10 (null-deref)
    #0 0x65da2b in spinel_datatype_vunpack_ wpantund/third_party/openthread/src/ncp/spinel.c:295:17
    #1 0x65dfb4 in spinel_datatype_unpack wpantund/third_party/openthread/src/ncp/spinel.c:638:11
    #2 0x618b9e in nl::wpantund::SpinelNCPInstance::handle_ncp_spinel_value_inserted(spinel_prop_key_t, unsigned char const*, unsigned int) wpantund/src/ncp-spinel/SpinelNCPInstance.cpp:2873:3
    #3 0x61a56a in nl::wpantund::SpinelNCPInstance::handle_ncp_spinel_callback(unsigned int, unsigned char const*, unsigned int) wpantund/src/ncp-spinel/SpinelNCPInstance.cpp:3002:11
    #4 0x62f70c in nl::wpantund::SpinelNCPInstance::ncp_to_driver_pump() wpantund/src/ncp-spinel/SpinelNCPInstance-DataPump.cpp:317:4
    #5 0x5b709e in nl::wpantund::NCPInstanceBase::process() wpantund/src/wpantund/NCPInstanceBase-AsyncIO.cpp:244:3
    #6 0x61cf0c in nl::wpantund::SpinelNCPInstance::process() wpantund/src/ncp-spinel/SpinelNCPInstance.cpp:3366:19
    #7 0x521af3 in MainLoop::process() wpantund/src/wpantund/wpantund.cpp:539:17
    #8 0x51f831 in NCPInputFuzzTarget(unsigned char const*, unsigned long) wpantund/src/wpantund/wpantund-fuzz.cpp:183:13
    #9 0x520242 in LLVMFuzzerTestOneInput wpantund/src/wpantund/wpantund-fuzz.cpp:242:11
```
