# Structure-Aware Fuzzing with libFuzzer

Generation-based fuzzers are fuzzers created specifically for a single input type.
They generate inputs according to a pre-defined grammar.
Good examples of such fuzzers are
[csmith](https://embed.cs.utah.edu/csmith/) (generates valid C programs)
and
[Peach](https://www.peach.tech/)
(generates inputs of any type, but requires such a
type to be expressed as a grammar definition).

Coverage-guided mutation-based fuzzers, like
[libFuzzer](http://libfuzzer.info) or
[AFL](http://lcamtuf.coredump.cx/afl/)
are not restricted to a single input type nor they require grammar definitions,
which is not only their strength, but also a weakness:
they are inefficient for fuzzing complicated inputs types because
any traditional mutation (e.g. bit flipping) leads to an invalid input
rejected by the target API in the early stage of parsing.

However, with some additional effort libFuzzer can be turned into a
grammar-aware (or, **structure-aware**) fuzzing engine for a specific input
type.

## Example: Compression

Let us start from a simple example, that demonstrates most of the aspects of
structure-aware fuzzing with libFuzzer.

Take a look at the
[example fuzz target](https://github.com/llvm-mirror/compiler-rt/blob/master/test/fuzzer/CompressedTest.cpp)
that consumes Zlib-compressed data, uncompresses
it, and crashes if the first two bytes of the uncompressed input are 'F' and 'U'.

```cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) {
  uint8_t Uncompressed[100];
  size_t UncompressedLen = sizeof(Uncompressed);
  if (Z_OK != uncompress(Uncompressed, &UncompressedLen, Data, Size))
    return 0;
  if (UncompressedLen < 2) return 0;
  if (Uncompressed[0] == 'F' && Uncompressed[1] == 'U')
    abort();  // Boom
  return 0;
}
```

Very simple target, yet the traditional universal fuzzers, libFuzzer included, have
virtually not chance of discovering the crash because they will mutate
compressed data causing the mutations to be invalid inputs for `uncompress`.

This is where **custom mutators**, or libFuzzer plugins, come into play.
The custom mutator is a user-defined function with a fixed signature that does
the following:
  * Parses the input data according to the specified language grammar (in our
    example, it uncompresses the data).
    * If parsing fails, it returns a syntactically correct dummy input (in our
      case, it returns a compressed byte sequence `Hi`).
  * Mutates the in-memory parsed representation of the input (in our case,
    uncompressed raw data). The custom mutator *may* request libFuzzer to
    mutate some part of the raw data
    via the function `LLVMFuzzerMutate`.
  * Serializes the in-memory representation (in our case, compresses it).

Let's run
[our example](https://github.com/llvm-mirror/compiler-rt/blob/master/test/fuzzer/CompressedTest.cpp).
First, let's compile the target alone, without the custom mutator:

```console
% clang -O -g CompressedTest.cpp -fsanitize=fuzzer -lz
% ./a.out
...
INFO: A corpus is not provided, starting from an empty corpus
#2      INITED cov: 2 ft: 3 corp: 1/1b lim: 4 exec/s: 0 rss: 25Mb
#2097152        pulse  cov: 2 ft: 3 corp: 1/1b lim: 4096 exec/s: 1048576 rss: 25Mb
#4194304        pulse  cov: 2 ft: 3 corp: 1/1b lim: 4096 exec/s: 1048576 rss: 25Mb
#8388608        pulse  cov: 2 ft: 3 corp: 1/1b lim: 4096 exec/s: 1198372 rss: 26Mb
#16777216       pulse  cov: 2 ft: 3 corp: 1/1b lim: 4096 exec/s: 1290555 rss: 26Mb
#33554432       pulse  cov: 2 ft: 3 corp: 1/1b lim: 4096 exec/s: 1342177 rss: 26Mb
#67108864       pulse  cov: 2 ft: 3 corp: 1/1b lim: 4096 exec/s: 1398101 rss: 26Mb
...
```

No luck. The coverage (`cov: 2`) doesn't grow because no new instrumented code in the target is executed.
Even if we also instrument Zlib, thus providing more coverage feedback during fuzzing,
libFuzzer is unlikely to discover the crash.

Now let's run the same target but this time with the custom mutator:

```console
% clang -O -g CompressedTest.cpp -fsanitize=fuzzer -lz -DCUSTOM_MUTATOR
% ./a.out
...
INFO: A corpus is not provided, starting from an empty corpus
#2      INITED cov: 2 ft: 3 corp: 1/1b lim: 4 exec/s: 0 rss: 25Mb
#512    pulse  cov: 2 ft: 3 corp: 1/1b lim: 8 exec/s: 256 rss: 26Mb
#713    NEW    cov: 3 ft: 4 corp: 2/11b lim: 11 exec/s: 237 rss: 26Mb L: 10/10 MS: 1 Custom-
#740    NEW    cov: 4 ft: 5 corp: 3/20b lim: 11 exec/s: 246 rss: 26Mb L: 9/10 MS: 3 Custom-EraseBytes-Custom-
#1024   pulse  cov: 4 ft: 5 corp: 3/20b lim: 11 exec/s: 341 rss: 26Mb
#2048   pulse  cov: 4 ft: 5 corp: 3/20b lim: 21 exec/s: 682 rss: 26Mb
#4096   pulse  cov: 4 ft: 5 corp: 3/20b lim: 43 exec/s: 1365 rss: 26Mb
#4548   NEW    cov: 5 ft: 6 corp: 4/30b lim: 48 exec/s: 1516 rss: 26Mb L: 10/10 MS: 6 ShuffleBytes-Custom-ChangeByte-Custom-InsertByte-Custom-
#8192   pulse  cov: 5 ft: 6 corp: 4/30b lim: 80 exec/s: 2730 rss: 26Mb
#16384  pulse  cov: 5 ft: 6 corp: 4/30b lim: 163 exec/s: 5461 rss: 26Mb
==157112== ERROR: libFuzzer: deadly signal...
    #7 0x4b024b in LLVMFuzzerTestOneInput CompressedTest.cpp:23:5
```

Here, every input that is received by the target function
(`LLVMFuzzerTestOneInput`) is a valid compressed data, that successfully
 uncompresses. The rest is the usual libFuzzer's behaviour.


## Example: PNG

[PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics)
is a raster-graphics file-format. A PNG file is a sequence of
length-tag-value-checksum chunks. This data format represents a challenge for
non-specialized mutation-based fuzzing engines for these reasons:
* Every chunk contains a CRC checksum
 (although [libpng](http://www.libpng.org) allows to disable CRC checking with a
 call to `png_set_crc_action`).
* Every chunk has a length, and thus a mutation that increases the size of a
  chunk also needs to change the stored length.
* Some chunks contain Zlib-compressed data, and the multiple `IDAT` chunks are
  parts of the same compressed data stream.

Here is an
[example of a fuzz target for libpng](https://github.com/google/oss-fuzz/blob/master/projects/libpng-proto/libpng_transforms_fuzzer.cc).
Non-specialized fuzzers could be relatively
effective for this target when CRC checking is disabled and a comprehensive seed
corpus is provided. But libFuzzer with a custom mutator
([example](../libpng-1.2.56/png_mutator.h))
will be much more effective. The
custom mutator parses the PNG file into an in-memory data structure, mutates it,
and serializes the mutant back to PNG.

This custom mutator does an extra twist: it randomly inserts and extra chunk
`fUZz` with a fixed-size value, that can later be interpreted by the fuzz target
as the instruction for extra actions on the input, to provide more coverage.

The resulting fuzzer achieves much higher coverage starting from an empty corpus
compared to the same target w/o the custom mutator, even with a good seed
corpus and interations.

## Example: Protocol Buffers

TODO

## Example: Protocol Buffers As Intermediate Format

TODO

## Example: Fuzzing Stateful APIs


## Links

* [libprotobuf-mutator](https://github.com/google/libprotobuf-mutator) -
  Mutator for protobufs.
* [Attacking Chrome IPC: Reliably finding bugs to escape the Chrome sandbox](https://media.ccc.de/v/35c3-9579-attacking_chrome_ipc)
* [Adventures in Fuzzing Instruction Selection](https://www.youtube.com/watch?v=UBbQ_s6hNgg&t=979s)
* [Structure-aware fuzzing for Clang and LLVM with libprotobuf-mutator](https://www.youtube.com/watch?v=U60hC16HEDY)
* [AFLSmart](https://arxiv.org/pdf/1811.09447.pdf) - combines AFL with Peach
  grammar definitions.
* [syzkaller](https://github.com/google/syzkaller) - kernel fuzzer
