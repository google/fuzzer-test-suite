This is a benchmark for the TiffDecoderFuzzer-PefDecoder target in [RawSpeed](https://github.com/darktable-org/rawspeed).

This benchmark finds an [abort: out of range](https://bugs.chromium.org/p/oss-fuzz/issues/detail?id=2831), and it takes a long time to find with libFuzzer.
Interestingly, this bug was first found with AFL in [OSS-Fuzz](https://github.com/google/oss-fuzz).

A reproducer is included for the crash, which is as follows:

```

terminate called after throwing an instance of 'std::out_of_range'
  what():  vector::_M_range_check: __n (which is 32) >= this->size() (which is 17)
==3187== ERROR: libFuzzer: deadly signal
    #0 0x50d543 in __sanitizer_print_stack_trace /home/dcalifornia/buildclang/llvm/projects/compiler-rt/lib/asan/asan_stack.cc:38
    #1 0x6bb601 in fuzzer::Fuzzer::CrashCallback() /home/dcalifornia/Fuzzer/FuzzerLoop.cpp:196:5
    #2 0x6bb5cd in fuzzer::Fuzzer::StaticCrashSignalCallback() /home/dcalifornia/Fuzzer/FuzzerLoop.cpp:175:6
    #3 0x7f52291af38f  (/lib/x86_64-linux-gnu/libpthread.so.0+0x1138f)
    #4 0x7f52287e7427 in gsignal (/lib/x86_64-linux-gnu/libc.so.6+0x35427)
    #5 0x7f52287e9029 in abort (/lib/x86_64-linux-gnu/libc.so.6+0x37029)
    #6 0x7f522975384c in __gnu_cxx::__verbose_terminate_handler() (/usr/lib/x86_64-linux-gnu/libstdc++.so.6+0x8f84c)
    #7 0x7f52297516b5  (/usr/lib/x86_64-linux-gnu/libstdc++.so.6+0x8d6b5)
    #8 0x7f5229751700 in std::terminate() (/usr/lib/x86_64-linux-gnu/libstdc++.so.6+0x8d700)
    #9 0x7f5229751918 in __cxa_throw (/usr/lib/x86_64-linux-gnu/libstdc++.so.6+0x8d918)
    #10 0x7f522977a3f6 in std::__throw_out_of_range_fmt(char const*, ...) (/usr/lib/x86_64-linux-gnu/libstdc++.so.6+0xb63f6)
    #11 0x6621c5 in std::vector<unsigned char, std::allocator<unsigned char> >::_M_range_check(unsigned long) const /usr/lib/gcc/x86_64-linux-gnu/5.4.0/../../../../include/c++/5.4.0/bits/stl_vector.h:803:4
    #12 0x6621c5 in std::vector<unsigned char, std::allocator<unsigned char> >::at(unsigned long) /usr/lib/gcc/x86_64-linux-gnu/5.4.0/../../../../include/c++/5.4.0/bits/stl_vector.h:824
    #13 0x6621c5 in rawspeed::PentaxDecompressor::SetupHuffmanTable_Modern(rawspeed::TiffIFD*) /home/dcalifornia/libraw/BUILD/src/librawspeed/decompressors/PentaxDecompressor.cpp:86
    #14 0x66297b in rawspeed::PentaxDecompressor::SetupHuffmanTable(rawspeed::TiffIFD*) /home/dcalifornia/libraw/BUILD/src/librawspeed/decompressors/PentaxDecompressor.cpp:121:10
    #15 0x6630dc in rawspeed::PentaxDecompressor::decompress(rawspeed::RawImage const&, rawspeed::ByteStream&&, rawspeed::TiffIFD*) /home/dcalifornia/libraw/BUILD/src/librawspeed/decompressors/PentaxDecompressor.cpp:132:21
    #16 0x5b1508 in rawspeed::PefDecoder::decodeRawInternal() /home/dcalifornia/libraw/BUILD/src/librawspeed/decoders/PefDecoder.cpp:83:5
    #17 0x5c52c8 in rawspeed::RawDecoder::decodeRaw() /home/dcalifornia/libraw/BUILD/src/librawspeed/decoders/RawDecoder.cpp:302:20
    #18 0x53bd95 in LLVMFuzzerTestOneInput /home/dcalifornia/libraw/BUILD/fuzz/librawspeed/decoders/TiffDecoders/main.cpp:81:14
    #19 0x6bc87d in fuzzer::Fuzzer::ExecuteCallback(unsigned char const*, unsigned long) /home/dcalifornia/Fuzzer/FuzzerLoop.cpp:495:13
    #20 0x6b1191 in fuzzer::RunOneTest(fuzzer::Fuzzer*, char const*, unsigned long) /home/dcalifornia/Fuzzer/FuzzerDriver.cpp:273:6
    #21 0x6b55f5 in fuzzer::FuzzerDriver(int*, char***, int (*)(unsigned char const*, unsigned long)) /home/dcalifornia/Fuzzer/FuzzerDriver.cpp:691:9
    #22 0x6b0f10 in main /home/dcalifornia/Fuzzer/FuzzerMain.cpp:20:10
    #23 0x7f52287d282f in __libc_start_main (/lib/x86_64-linux-gnu/libc.so.6+0x2082f)
    #24 0x43f558 in _start (/home/dcalifornia/libraw/TiffDecoderFuzzer-PefDecoder+0x43f558)

NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
SUMMARY: libFuzzer: deadly signal

```

