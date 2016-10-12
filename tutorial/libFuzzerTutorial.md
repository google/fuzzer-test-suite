# libFuzzer Tutorial

## Introduction
In this tutorial you will learn how to use [libFuzzer](http://libfuzzer.info)
(a coverage-guided in-process fuzzing engine)
and [AddressSanitizer](http://clang.llvm.org/docs/AddressSanitizer.html)
(dynamic memory error detector for C/C++).

Prerequisites: experience with C/C++ and Unix shell. 

## Setup a VM
* Login into your [GCE](https://cloud.google.com/compute/) account or create one.
* Create a new VM and ssh to it
   * Ubuntu 14.04 LTS is recommended, other VMs may or may not work
   * Choose as many CPUs as you can
   * Choose "Access scopes" = "Allow full access to all Cloud APIs"
* Install dependencies: 

```
# Install git and get this tutorial
sudo apt-get --yes install git
git clone https://github.com/google/fuzzer-test-suite.git FTS
./FTS/tutorial/install-deps.sh  # Get deps
./FTS/tutorial/install-clang.sh # Get fresh clang binaries
# Get libFuzzer sources and build it
svn co http://llvm.org/svn/llvm-project/llvm/trunk/lib/Fuzzer
Fuzzer/build.sh
```

## 'Hellow world' fuzzer
Definition:
a **fuzz target** is a function that has the following signature and does something interesting with it's arguments:
```
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
  DoSomethingWitData(Data, Size);
  return 0;
}
```

Take a look at an example of such **fuzz target**: [./fuzz_me.cc](fuzz_me.cc). Can you see the bug?

To build a fuzzer binary for this target you need to compile the source using the recent Clang compiler 
with the following extra flags:
* `-fsanitize-coverage=trace-pc-guard` (required): provides in-process coverage information to libFuzzer.
* `-fsanitize=address` (recommended): enables AddressSanitizer
* `-g` (recommended): enables debug info, makes the error messages easier to read. 

Then you need to link the target code with `libFuzzer.a` which provides the `main()` function. 
```
clang++ -g -fsanitize=address -fsanitize-coverage=trace-pc-guard FTS/tutorial/fuzz_me.cc libFuzzer.a
```
Now try running it:
```
./a.out
```
You will see something like this:
```
INFO: Seed: 3918206239
INFO: Loaded 1 modules (14 guards): [0x73be00, 0x73be38), 
INFO: -max_len is not provided, using 64
INFO: A corpus is not provided, starting from an empty corpus
#0      READ units: 1
#1      INITED cov: 3 ft: 3 corp: 1/1b exec/s: 0 rss: 26Mb
#8      NEW    cov: 4 ft: 4 corp: 2/29b exec/s: 0 rss: 26Mb L: 28 MS: 2 InsertByte-InsertRepeatedBytes-
#3405   NEW    cov: 5 ft: 5 corp: 3/82b exec/s: 0 rss: 27Mb L: 53 MS: 4 InsertByte-EraseBytes-...
#8664   NEW    cov: 6 ft: 6 corp: 4/141b exec/s: 0 rss: 27Mb L: 59 MS: 3 CrossOver-EraseBytes-...
#272167 NEW    cov: 7 ft: 7 corp: 5/201b exec/s: 0 rss: 51Mb L: 60 MS: 1 InsertByte-
=================================================================
==2335==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x602000155c13 at pc 0x0000004ee637...
READ of size 1 at 0x602000155c13 thread T0
    #0 0x4ee636 in FuzzMe(unsigned char const*, unsigned long) FTS/tutorial/fuzz_me.cc:10:7
    #1 0x4ee6aa in LLVMFuzzerTestOneInput FTS/tutorial/fuzz_me.cc:14:3
...
artifact_prefix='./'; Test unit written to ./crash-0eb8e4ed029b774d80f2b66408203801cb982a60
...
```
Do you see a similar output? Congratulations, you have built a fuzzer and found a bug.
Let us look at the output. 


```
INFO: Seed: 3918206239
```
The fuzzer has started with this random seed. Rerun it with `-seed=3918206239` to get the same result.

```
INFO: -max_len is not provided, using 64
INFO: A corpus is not provided, starting from an empty corpus
```
By default, libFuzzer assumes that all inputs are 64 bytes or smaller.
To change that either use `-max_len=N` or run with a non-empty [seed corpus](#seedcorpus).

```
#0      READ units: 1
#1      INITED cov: 3 ft: 3 corp: 1/1b exec/s: 0 rss: 26Mb
#8      NEW    cov: 4 ft: 4 corp: 2/29b exec/s: 0 rss: 26Mb L: 28 MS: 2 InsertByte-InsertRepeatedBytes-
#3405   NEW    cov: 5 ft: 5 corp: 3/82b exec/s: 0 rss: 27Mb L: 53 MS: 4 InsertByte-EraseBytes-...
#8664   NEW    cov: 6 ft: 6 corp: 4/141b exec/s: 0 rss: 27Mb L: 59 MS: 3 CrossOver-EraseBytes-...
#272167 NEW    cov: 7 ft: 7 corp: 5/201b exec/s: 0 rss: 51Mb L: 60 MS: 1 InsertByte-
```
libFuzzer has tried at least 272167 inputs (`#272167`)
and has discovered 5 inputs of 201 bytes total (`corp: 5/201b`)
that together cover 7 coverage points (`cov: 7`).
```
=================================================================
==2335==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x602000155c13 at pc 0x0000004ee637...
READ of size 1 at 0x602000155c13 thread T0
    #0 0x4ee636 in FuzzMe(unsigned char const*, unsigned long) FTS/tutorial/fuzz_me.cc:10:7
    #1 0x4ee6aa in LLVMFuzzerTestOneInput FTS/tutorial/fuzz_me.cc:14:3
```
On one of the inputs AddressSanitizer has detected a `heap-buffer-overflow` bug and aborted the execution. 

```
artifact_prefix='./'; Test unit written to ./crash-0eb8e4ed029b774d80f2b66408203801cb982a60
```
Before exiting the process libFuzzer has created a file on disc with the bytes that triggered the crash. 
Take a look at ths file. What do you see? Why did it trigger the crash? 

To reproduce the crash again w/o fuzzing run 
```
./a.out crash-0eb8e4ed029b774d80f2b66408203801cb982a60
```

## Seed corpus {#seedcorpus}
