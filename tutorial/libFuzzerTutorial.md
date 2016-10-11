# libFuzzer Tutorial

## VM setup
* Login into your [GCE](https://cloud.google.com/compute/) account or create one.
* Create a new VM and ssh to it
   * Ubuntu 14.04 LTS is recommended, other VMs may or may not work
   * Choose as many CPUs as you can
   * Choose "Access scopes" = "Allow full access to all Cloud APIs"
* Set up the VM: 
```
 sudo apt-get --yes install git 
 git clone https://github.com/google/fuzzer-test-suite.git FTS
 ./FTS/tutorial/install-deps.sh
 ./FTS/tutorial/install-clang.sh
 svn co http://llvm.org/svn/llvm-project/llvm/trunk/lib/Fuzzer
 Fuzzer/build.sh
 ```

## Toy fuzzer
* Build a tiny fuzzer for a [toy target function](fuzz_me.cc) and try running it
```
clang++ -g -fsanitize=address -fsanitize-coverage=edge FTS/tutorial/fuzz_me.cc libFuzzer.a -o toy
./toy
```
You will see something like this:
```
INFO: Seed: 1816590574
INFO: -max_len is not provided, using 64
INFO: A corpus is not provided, starting from an empty corpus
#0      READ units: 1
#1      INITED cov: 3 corp: 1/1b exec/s: 0 rss: 28Mb
#14     NEW    cov: 4 corp: 2/49b exec/s: 0 rss: 28Mb L: 48 MS: 3 ChangeByte-ChangeByte-InsertRepeatedBytes-
#18171  NEW    cov: 5 corp: 3/113b exec/s: 0 rss: 30Mb L: 64 MS: 5 InsertRepeatedBytes-InsertRepeatedBytes-InsertRepeatedBytes-ChangeByte-CrossOver-
#44053  NEW    cov: 6 corp: 4/177b exec/s: 0 rss: 32Mb L: 64 MS: 2 InsertByte-CrossOver-
#53201  NEW    cov: 7 corp: 5/230b exec/s: 0 rss: 33Mb L: 53 MS: 5 ChangeBit-EraseBytes-ChangeBinInt-InsertRepeatedBytes-InsertRepeatedBytes-
=================================================================
==9454==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x6020000535f3 at pc 0x0000004ee661 bp 0x7fffdded4600 sp 0x7fffdded45f8
READ of size 1 at 0x6020002c73f3 thread T0
    #0 0x4ee660 in FuzzMe(unsigned char const*, unsigned long) FTS/tutorial/fuzz_me.cc:10:7
    #1 0x4ee6d1 in LLVMFuzzerTestOneInput FTS/tutorial/fuzz_me.cc:14:3
```
