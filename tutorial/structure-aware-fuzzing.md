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
they are inefficient for fuzzing complicated input types because
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

Interface Definition Languages (IDLs), such as
[Protocol Buffers](https://developers.google.com/protocol-buffers/) (aka protobufs),
[Mojo](https://chromium.googlesource.com/chromium/src/+/master/mojo/README.md),
[FIDL](https://fuchsia.googlesource.com/docs/+/master/development/languages/fidl/README.md),
or [Thrift](https://thrift.apache.org/)
are all good examples of highly structured input types that are hard to fuzz
with generic mutation-based fuzzers.

Structure-aware fuzzing for IDLs is possible with libFuzzer using custom
mutators. One such mutator is implemented for protobufs:
[libprotobuf-mutator](https://github.com/google/libprotobuf-mutator) (aka LPM).

Let's look at the
[example proto definition](https://github.com/google/libprotobuf-mutator/blob/master/examples/libfuzzer/libfuzzer_example.proto)
and the corresponding
[fuzz target](https://github.com/google/libprotobuf-mutator/blob/master/examples/libfuzzer/libfuzzer_example.cc).

```protobuf
message Msg {
  optional float optional_float = 1;
  optional uint64 optional_uint64 = 2;
  optional string optional_string = 3;
}
```

```cpp
DEFINE_PROTO_FUZZER(const libfuzzer_example::Msg& message) {
  // Emulate a bug.
  if (message.optional_string() == "FooBar" &&
      message.optional_uint64() > 100 &&
      !std::isnan(message.optional_float()) &&
      std::fabs(message.optional_float()) > 1000 &&
      std::fabs(message.optional_float()) < 1E10) {
    abort();
  }
}

```

Here the crash will happen if the 3 fields of the message have specific values.

Note that LPM provides a convenience macro `DEFINE_PROTO_FUZZER` to define a
fuzz target that directly consumes a protobuf message.

Here are some real life examples of fuzzing protobuf-based APIs with libFuzzer
and LPM:
* [config_fuzz_test](https://github.com/envoyproxy/envoy/blob/568b2573341151b2d9f3c7e7db6ebb33380029c8/test/server/config_validation/config_fuzz_test.cc)
fuzzes the [Envoy](https://github.com/envoyproxy/envoy) configuration API.
* TODO

## Protocol Buffers As Intermediate Format

Protobufs provide a convenient way to serialize structured data,
and LPM provides an easy way to mutate protobufs for structure-aware fuzzing.
Thus, it is tempting to use libFuzzer+LPM for APIs that consume structured data
other than protobufs.

When fuzzing a data format `Foo` with LPM, these steps need to be made:
* Describe `Foo` as a protobuf message, say `FooProto`. Precise mapping from Foo
  to protobufs may not be possible, so `FooProto` may describe a subset of a superset of `Foo`.
* Implement a `FooProto` => `Foo` converter.
* Optionally implement a `Foo => FooProto`. This is more important if an
  extensive corpus of `Foo` inputs is available.

Below we discuss several real-life examples of this approach.

### Example: SQLite

In Chromium, the SQLite database library backs many features, including WebSQL, which exposes SQLite to arbitrary websites and makes SQLite an interesting target for malicious websites. Because SQLite of course uses the highly structured, text-based SQL language, it is a good candidate for structure-aware fuzzing. Furthermore, it has a [very good description](https://www.sqlite.org/lang.html) of the language it consumes.

The first step is to convert this grammar into the protobuf format, which can be seen [in the Chromium source tree](https://chromium.googlesource.com/chromium/src/third_party/+/refs/heads/master/sqlite/fuzz/sql_query_grammar.proto). As a quick, simplified example, if we only wanted to fuzz the CREATE TABLE sql statement, we could make a protobuf grammar as such:

```protobuf
message SQLQueries {
    repeated CreateTable queries = 1;
}

message CreateTable {
    optional TempModifier temp_table = 1;
    required Table table = 2;
    required ColumnDef col_def = 3;
    repeated ColumnDef extra_col_defs = 4;
    repeated TableConstraint table_constraints = 5;
    required bool without_rowid = 6;
}

// Further definitions of TempModifier, Table, ColumnDef, and TableConstraint.
```

Then, we write the C++ required to convert the structured protobufs into actual textual SQL queries (the full version can be seen [in the Chromium source tree](https://chromium.googlesource.com/chromium/src/third_party/+/refs/heads/master/sqlite/fuzz/sql_query_proto_to_string.cc)):
```cpp
// Converters for TempModifier, Table, ColumnDef, and TableConstraint go here.

std::string CreateTableToString(const CreateTable& ct) {
    std::string ret("CREATE TABLE ");
    if (ct.has_temp_table()) {
        ret += TempModifierToString(ct.temp_table());
        ret += " ";
    }
    ret += TableToString(ct.table());
    ret += "(";
    ret += ColumnDefToString(ct.col_def());
    for (int i = 0; i < ct.extra_col_defs_size(); i++) {
        ret += ", ";
        ret += ColumnDefToString(ct.extra_col_defs(i));
    }
    for (int i = 0; i < ct.table_constraints_size(); i++) {
        ret += ", ";
        ret += TableConstraintToString(ct.table_constraints(i));
    }
    ret += ") ";
    if (ct.without_rowid())
        ret += "WITHOUT ROWID ";
    return ret;
}

std::string SQLQueriesToString(const SQLQueries& queries) {
    std::string queries;
    for (int i = 0; i < queries.queries_size(); i++) {
        queries += CreateTableToString(queries.queries(i));
        queries += ";\n";
    }
    return queries;
}
```

And finally, we write our fuzz target:
```cpp
DEFINE_BINARY_PROTO_FUZZER(const SQLQueries& sql_queries) {
    std::string queries = SQLQueriesToString(sql_queries);
    sql_fuzzer::RunSQLQueries(SQLQueriesToString(queries)); // Helper that passes our queries to sqlite library to execute
}
```

With luck, libFuzzer and LPM will be able to create many interesting CREATE TABLE statements, with varying numbers of columns, table constraints, and other attributes. This basic definition of SQLQueries can be expanded to work with other SQL statements like INSERT or SELECT, and with care we can cause these other statements to insert or select from the tables created by the random CREATE TABLE statements. Without defining this protobuf structure, it's very difficult for a fuzzer to be able to generate valid CREATE TABLE statements that actually create tables without causing parsing errors--especially tables with valid table constraints.

### Example: Chrome IPC Fuzzer

TODO: add links, 1-2 paragraphs description.

* [Attacking Chrome IPC: Reliably finding bugs to escape the Chrome sandbox](https://media.ccc.de/v/35c3-9579-attacking_chrome_ipc)

## Fuzzing Stateful APIs

So far we have discussed fuzzing for APIs that consume a single structured input.
Some APIs could be very different. An API may not consume data directly at all,
and it could consist of many functions that work only when the API is in a certain
state. Such **stateful APIs** are common for e.g. networking software.
Fuzzing with protobufs could be useful here as well. All you need is to define a
protobuf message describing a sequence of API calls and implement a function to
*play* the message.

TODO

### Example: gRPC API Fuzzer
The
[gRPC](https://github.com/grpc/grpc)'s
[API Fuzzer](https://github.com/grpc/grpc/blob/86953f66948aaf49ecda56a0b9f87cdcf4b3859a/test/core/end2end/fuzzers/api_fuzzer.cc)
is actually not using libFuzzer's custom mutator or protobufs.
But it's still a good and simple example of fuzzing a stateful API.
The fuzzer consumes an array of bytes and every individual byte is
interpreted as a single call to a specific API function
(in some cases, following bytes are used as parameters).

```cpp
    switch (grpc_fuzzer_get_next_byte(&inp)) {
      default:
      // terminate on bad bytes
      case 0: {
        grpc_event ev = grpc_completion_queue_next(...
      case 1: {
        g_now = gpr_time_add(...
```

This fuzz target is compatible with any mutation-based fuzzing engine
and has resulted in over
[80 bug reports](https://bugs.chromium.org/p/oss-fuzz/issues/list?can=1&q=label%3AProj-grpc+api_fuzzer+&colspec=ID+Type+Component+Status+Proj+Reported+Owner+Summary&cells=ids),
some discovered with libFuzzer and some with AFL.

However, a drawback of this approach is that the inputs created by the fuzzer are
meaningless outside of the fuzz target itself and will stop working with a slight
change in the target. They are also not human readable, which makes analysis of
such bugs complicated.


### Example TODO
### Example TODO


## Related Links

* [libprotobuf-mutator](https://github.com/google/libprotobuf-mutator) -
  Mutator for protobufs.
* [Adventures in Fuzzing Instruction Selection](https://www.youtube.com/watch?v=UBbQ_s6hNgg&t=979s):
  using libFuzzer with a custom mutator for LLVM IR to find bugs in LLVM
  optimization passes.
* [Structure-aware fuzzing for Clang and LLVM with libprotobuf-mutator](https://www.youtube.com/watch?v=U60hC16HEDY)
* [AFLSmart](https://arxiv.org/pdf/1811.09447.pdf) - combines AFL with Peach
  grammar definitions.
* [syzkaller](https://github.com/google/syzkaller) - kernel fuzzer
