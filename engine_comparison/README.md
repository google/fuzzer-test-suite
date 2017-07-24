# Engine Comparison

This is a set of scripts to run A/B testing among different fuzzing engines.

## gcloud

The `gcloud` CLI is a part of the [Google Cloud SDK](https://cloud.google.com/sdk/gcloud/),
which can be installed [here](https://cloud.google.com/sdk/downloads).

Currently, these scripts only run on Google Cloud, but support for alternatives will be incorporated.

## Usage

From one's local computer, call ` ${FTS}/engine_comparison/begin_experiment.sh
<list of benchmarks> <fuzz engine config1> <fuzz engine config2>...`

The first arugment, the list of benchmarks, should be a comma-separated list of names,
or an alias such as `all`. Specifically, the name of an individual benchmark is the name of
the directory which contains that benchmark's build script (in the root of this repo).

All of the succeeding arguments specify unique fuzzing engines. In particular,
each of these arguments should be the path to a bash script; the script then
configures a particular fuzzing engine exclusively by defining environment variables.

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

The result of these parameters is that each benchmark will be built with each
fuzzing engine, so if there are `B` benchmarks and `K` fuzzing engine
configurations, we will build `B * K` fuzzing binaries.

## Parameters

Script behavior can be modified through a variety of environment variables,
including

- `N_ITERATIONS`
- `JOBS`
