Finds an assertion failure in [guetzli](https://github.com/google/guetzli).

Can be found in up to an hour, sometimes much faster, using the provided seeds and fuzzer flags.

```
guetzli/output_image.cc:398: void guetzli::OutputImage::SaveToJpegData(guetzli::JPEGData*) const: Assertion `coeff % quant == 0' failed.
==34794== ERROR: libFuzzer: deadly signal
    #0 0x4c4597 in __sanitizer_print_stack_trace 
    #1 0x526741 in fuzzer::Fuzzer::CrashCallback() 
    #2 0x52670d in fuzzer::Fuzzer::StaticCrashSignalCallback() 
    ...
    #7 0x7f2f8fe71ca1 in __assert_fail 
    #8 0x509909 in guetzli::OutputImage::SaveToJpegData(guetzli::JPEGData*) const 
    #9 0x4f5f65 in guetzli::(anonymous namespace)::Processor::TryQuantMatrix(guetzli::JPEGData const&, float, int (*) [64], guetzli::OutputImage*) 
    #10 0x4f830a in SelectQuantMatrix 
    #11 0x4f830a in guetzli::(anonymous namespace)::Processor::ProcessJpegData(guetzli::Params const&, guetzli::JPEGData const&, guetzli::Comparator*, guetzli::GuetzliOutput*, guetzli::ProcessStats*) 
    #12 0x4fa196 in ProcessJpegData 
    #13 0x4fa196 in guetzli::Process(guetzli::Params const&, guetzli::ProcessStats*, std::string const&, std::string*) 
    #14 0x4ea17a in LLVMFuzzerTestOneInput 
```


