# Engine Comparison

This is a set of scripts to run A/B testing among different fuzzing engines.

## Gcloud

Currently, these scripts only run on Google Cloud, but support for alternatives will be incorporated.

### Gcloud Usage

Before running experiments, an initial VM has to be made. You can use
`gcloud-creator.sh` to create the initial VM, or `begin-experiment` can
automatically create this VM.
Creating a VM can take 45-60 seconds, but `gcloud-creator.sh` doesn't exit until google
cloud is ready for `begin-experiment.sh` to run; one needs only to wait for the
"Instance Created" output message.

In general, `gcloud` commands don't complete until the task is fully finished,
but there is sometimes a small latency.

VM status can also be found on [the gcloud
console](https://pantheon.corp.google.com/compute/instances?project=fuzzer-test-suite)

VM naming is automatic, so only one argument is used. To create the initial VM
manually, first call as follows:

```
${FTS}/engine-comparison/gcloud-creator.sh create
```
Again, this step is optional, and `begin-experiment` will call this automatically.

Similarly, when done for the day, one should call

```
${FTS}/engine-comparison/gcloud-creator.sh delete
```

Deleting is not optional, and should be done to avoid excessive charges
### Installation

The `gcloud` CLI is a part of the [Google Cloud SDK](https://cloud.google.com/sdk/gcloud/),
which can be installed [here](https://cloud.google.com/sdk/downloads).


## Script usage

From one's local computer, call ` ${FTS}/engine-comparison/begin-experiment.sh
<list of benchmarks> <fuzz-engine-1 config> <fuzz-engine-2 config>...<fuzz-engine-K config>`

These arguments specify benchmarks and fuzzing engines, and the harness will build
each benchmark with each fuzzing engine. Therefore, choosing `B` benchmarks
and `K` unique fuzzing engines will build `B * K` fuzzing binaries.

### Specify Benchmarks

The first argument, the list of benchmarks, should be a comma-separated list of names,
or an alias such as `all`. Specifically, the name of an individual benchmark is the name of
the directory which contains that benchmark's build script (in the root of this repo).

### Specify Fuzzing Engines

All arguments succeeding the first specify unique fuzzing engines. In particular,
each of these arguments should be the path to a bash script; the script then
configures a particular fuzzing engine exclusively by defining environment variables.

The name of each file is used in naming VMs which run the fuzzing engine, so to
follow gcloud naming conventions, please restrict these filenames to numbers,
letters, and dashes only.

The following environment variables are "magic", so they have special meaning in
the comparison harness:

- `$FUZZING_ENGINE`, which should be either `"afl"` or `"libfuzzer"`
- `$BINARY_RUNTIME_OPTIONS`, which will be evaluated for use on the command
  line with the fuzzing
  binary when the binary is called and fuzzing begins. For example, one could
  define `BINARY_RUNTIME_OPTIONS="-use-value-profile=1"` when using libfuzzer.

Any other (non-magic) environment variables which are declared in a fuzzing engine
configuration will not be accessed by the experiment harness, but they will
propagate directly to the environments for

1. Building this particular fuzzing engine
2. Building the binaries which fuzz each benchmark using this particular fuzzing engine.
3. Running each of these binaries


## Parameters

Script behavior can be modified through a set of parameters which are defined in
`parameters.cfg`. They are assigned with default values, but they can be changed
by the user before running `begin-experiment.sh`. These parameters are:

- `N_ITERATIONS`, the number of times each binary will be run (and measured).
Each iteration will be run until the benchmark is completed, except with regards
to time limits.
- `JOBS` specifies how many threads to use in running each binary.

