# Engine Comparison

Tool for executing A/B tests between different fuzzing configurations.

## Design

Given a set of benchmarks from this repository and a set of fuzzing
configurations (fuzzing engine, runtime flags, etc.), this tool fuzzes the
benchmarks under each fuzzing configuration and produces a comparison report
with coverage graphs for each benchmark.

![diagram](../docs/images/ab-design.png?raw=true)

The tool first spawns a **dispatcher** VM in Google Cloud which begins building
each benchmark with each fuzzing configuration.  As builds finish, the
dispatcher spawns **runner** VMs and copies the built fuzzers to them.

The runners then execute the fuzzers and capture periodic snapshots of the
produced corpus, uploading those snapshots to a Google Storage bucket.

Once the dispatcher has finished building all the fuzzers, it starts pulling the
snapshots from Google Cloud Storage and measuring the coverage produced by each
corpus snapshot.  It also creates a live web report with coverage graphs for
each benchmark.  As new data becomes available, the web report is automatically
updated.

After a user-specified number of fuzzer iterations or time limit, each runner
kills its fuzzer and sends a final snapshot to Google Cloud Storage.  Included
in the final snapshot are summary statistics and any crash reproducers.  If the
user has specified multiple trials to be executed, the runner will run the
fuzzer again, uploading new snapshots, until all trials have been completed.
Runners automatically shut down and delete themselves when finished with all
trials.

When all runners are finished executing and the dispatcher has processed all of
their snapshots, the dispatcher also shuts itself down.

## Prerequisites

- Install [Google Cloud SDK](https://cloud.google.com/sdk/downloads).

## Configuration

Before starting an experiment, you first need to specify the fuzzing
configurations you wish to compare and the experiment parameters.

### Fuzzing Configurations

Fuzzing configurations are simply text files containing environment variables to
be exported.  Any variables defined in a configuration will be exported prior to
building and executing the corresponding benchmark fuzzers.  This means that you
can specify both build flags (e.g. `CC`, `CFLAGS`, `CXXFLAGS`) and runtime flags
(see `BINARY_RUNTIME_OPTIONS` below) in fuzzing configurations.

The following two environment variables have special meaning in fuzzing
configurations:

- `FUZZING_ENGINE` - Currently `afl` and `libfuzzer` are supported.
- `BINARY_RUNTIME_OPTIONS` - Flags to pass to the fuzzer binary.

**Note that the names of configuration files must contain alphanumeric
characters and dashes only.**  This restriction is due to GCP allowing only
those characters for VM names.

#### Example

Suppose you would like to run AFL with default build flags and an input timeout
of 25 seconds.  Then you could define a configuration file called `afl-config`
with the following contents:
```
export FUZZING_ENGINE="afl"
export BINARY_RUNTIME_OPTIONS="-t 25000"
```

### Experiment Parameters

Experiment parameters are defined in
[engine-comparison/config/parameters.cfg](config/parameters.cfg) and have the
following meanings:

- `EXPERIMENT` - The name of this experiment.  Used to create unique links to
  web reports and storage locations for this experiment's data.  Must contain
  only alphanumeric characters and dashes.
- `N_ITERATIONS` - The number of trials to perform (i.e. how many times to run
  each fuzzer). Must be at least 1.
- `JOBS` - How many threads to run for each fuzzer.  Currently `JOBS=1` is the
  only supported mode.
- `RUNS` - How many individual inputs to run before killing a fuzzer. If
  -1, run indefinitely.
- `MAX_TOTAL_TIME` - How long to run each fuzzer before killing it.  If 0, run
  indefinitely.

## Usage

`${FTS}/engine-comparison/begin-experiment.sh benchmark1[,benchmark2,...]
fuzz-config1 [fuzz-config2 ...]`

Each benchmark in the comma-separated list must be the name of a benchmark
folder in this repository.  Alternatively, the word `all` can be used to run on
all benchmarks.

Each fuzzing configuration is specified by a path to its
[configuration file](#fuzzing-configurations).

### Example

Suppose you would like to compare two fuzzing configurations located at
`./config/afl` and `./config/libfuzzer` on the boringssl, freetype, and guetzli
benchmarks.  The corresponding script invocation would be:

`${FTS}/engine-comparison/begin-experiment.sh
boringssl-2016-02-12,freetype2-2017,guetzli-2017-3-30 ./config/afl
./config/libfuzzer`
