# Engine Comparison

This is a set of scripts to run A/B testing among different fuzzing engines.

## gcloud

The `gcloud` CLI is a part of the [Google Cloud SDK](https://cloud.google.com/sdk/gcloud/), which can be installed [here](https://cloud.google.com/sdk/downloads).

Currently, these scripts only run on Google Cloud, but support for alternatives will be incorporated.

## Usage

From one's local computer, call ` ${FTS}/engine_comparison/begin_experiment.sh
<list of benchmarks> <fuzzing engine configuration> <more configurations>...`

The list of benchmarks should be a comma-separated list of names, or an alias
such as `all`.

All other arguments specify unique fuzzing engines. In particular, each of these
arguments should be the paths to a bash script which defines particular
environment variables. "Magic" variables include
define

- `$FUZZING_ENGINE`, to be either `"afl"` or `"libfuzzer"`
- `$BINARY_RUNTIME_OPTIONS`, which will be evaluated and used with the fuzzing
  binary when the binary is called and fuzzing begins. For example, one could
  define `BINARY_RUNTIME_OPTIONS="use-value-profile=1"` when using libfuzzer.

Any other environment variables which are declared here will propagate to the
scripts which
proceed, in particular variables used for building and instrumenting each binary.

## Parameters

Script behavior can be modified through a variety of environment variables,
including

- `N_ITERATIONS`
- `JOBS`
