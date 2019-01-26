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

## Exaple: Compression

Let us start from a simple example, that demonstrates most of the aspects of
structure-aware fuzzing with libFuzzer.

Take a look at the
[example fuzz target](https://github.com/llvm-mirror/compiler-rt/blob/master/test/fuzzer/CompressedTest.cpp)
that consumes Zlib-compressed data, uncompresses
it, and crashes if the furst two bytes of the uncompresses input are 'F' and 'U'.

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

There is where **custom mutators**, or libFuzzer plugins, come into play.


TODO

## Example: PNG

TODO

## Example: Protocol Buffers

TODO

## Example: Protocol buffers As Intermediate Format

## Links

* [libprotobuf-mutator](https://github.com/google/libprotobuf-mutator) -
  Mutator for protobufs.
* [Attacking Chrome IPC: Reliably finding bugs to escape the Chrome sandbox](https://media.ccc.de/v/35c3-9579-attacking_chrome_ipc)
* [Adventures in Fuzzing Instruction Selection](https://www.youtube.com/watch?v=UBbQ_s6hNgg&t=979s)
* [Structure-aware fuzzing for Clang and LLVM with libprotobuf-mutator](https://www.youtube.com/watch?v=U60hC16HEDY)
* [AFLSmart](https://arxiv.org/pdf/1811.09447.pdf) - combines AFL with Peach
  grammar definitions.
