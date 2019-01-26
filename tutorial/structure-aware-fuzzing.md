# Structure-aware fuzzing

This section describes **structure-aware coverage-guided mutation-based fuzzing** (woof!).

Generation-based fuzzers are fuzzers created specifically for a single input type.
The generate inputs type according to a pre-defined grammar.
Good examples of such fuzzers are
[csmith](https://embed.cs.utah.edu/csmith/) (generates C programs)
and
[Peach](https://www.peach.tech/)
(generates inputs of any type, but requires that
type to be expressed as a grammar definition).

Coverage-guided mutation-based fuzzers, like
[libFuzzer](http://libfuzzer.info) or
[AFL](http://lcamtuf.coredump.cx/afl/)
are not restricted to a single input type nor they require grammar definitions,
which is both their strength (universality) and weakness:
They are weak against some complicated inputs types because
any traditional mutation (e.g. bit flipping) leads to an invalid input
rejected by the target in the early stage.

However, with some additional effort libFuzzer can be turned into a
grammar-aware (or, **structure-aware**) fuzzing engine for a specific input
type.

## Exaple: compression

TODO

## Example: PNG

TODO

## Example: protobufs

TODO

## Links

* [libprotobuf-mutator](https://github.com/google/libprotobuf-mutator) -
  Mutator for protobufs.
* [Attacking Chrome IPC: Reliably finding bugs to escape the Chrome sandbox](https://media.ccc.de/v/35c3-9579-attacking_chrome_ipc)
* [Adventures in Fuzzing Instruction Selection](https://www.youtube.com/watch?v=UBbQ_s6hNgg&t=979s)
* [Structure-aware fuzzing for Clang and LLVM with libprotobuf-mutator](https://www.youtube.com/watch?v=U60hC16HEDY)
* [AFLSmart](https://arxiv.org/pdf/1811.09447.pdf) - combines AFL with Peach
  grammar definitions.
