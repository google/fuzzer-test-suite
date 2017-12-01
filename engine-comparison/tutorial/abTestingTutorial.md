# A/B Testing Tutorial

## Introduction

In this tutorial, you will learn how to set up and run experiments comparing two
fuzzing configurations on a set of benchmarks.

## Prerequisites

- Install [Google Cloud SDK](https://cloud.google.com/sdk/downloads).

## Set Up the Environment

Since most of the experiment runs in Google Cloud, environment setup is minimal.
Just install Git and clone this repository.
```shell
sudo apt-get --yes install git
git clone https://github.com/google/fuzzer-test-suite.git FTS
```

## Getting Started

To get your feet wet, we'll run a short and simple experiment comparing AFL and
libFuzzer on a small number of benchmarks.

### Fuzzing Configurations

First, take a look at the supplied `afl-vanilla` configuration.
```shell
cat FTS/engine-comparison/tutorial/config/afl-vanilla
```
The configuration contains two lines.  This first line specifies AFL as the
fuzzing engine while the second line tells the testing framework to run AFL with
the `-t 25000` option specified on the command line.  For AFL, `-t 25000` means
to stop fuzzing if an input takes longer than 25 seconds to execute.

Now take a look at the `lf-vanilla` configuration.
```shell
cat FTS/engine-comparison/tutorial/config/lf-vanilla
```
This configuration sets libFuzzer as the fuzzing engine and also instructs the
testing framework to run libFuzzer with the `-timeout=25` option.  `-timeout=25`
is analogous to AFL's `-t 25000`.

### Experiment Parameters

Now take a look at the supplied `afl-lf.cfg` file.
```shell
cat FTS/engine-comparison/tutorial/param/afl-lf.cfg
```
This file defines the parameters of our experiment as follows.

- `EXPERIMENT="afl-libfuzzer"` - Names the experiment `afl-libfuzzer`.  This
  determines the URL at which results will be displayed.
- `N_ITERATIONS=2` - Specifies 2 trials to be performed per fuzzer.
- `JOBS=1` - Each fuzzer will run single-threaded.
- `RUNS=-1` - Trials will not be limited by number of inputs run.
- `MAX_TOTAL_TIME=300` - Trials will end after 300 seconds (5 minutes).

### Starting the Experiment

To run a comparison between the `afl-vanilla` and `lf-vanilla` configurations,
select a few benchmarks from the root of this repository and pass them to the
`begin-experiment.sh` script along with the experiment parameters file and the
two fuzzing configuration files.
```shell
FTS/engine-comparison/begin-experiment.sh boringssl-2016-02-12,freetype2-2017,harfbuzz-1.3.2 FTS/engine-comparison/tutorial/param/afl-lf.cfg FTS/engine-comparison/tutorial/config/afl-vanilla FTS/engine-comparison/tutorial/config/lf-vanilla
```

Observe the script output as it creates a dispatcher VM, copies the necessary
files to it, and sets up a Docker image.  When this is finished, the dispatcher
will begin building the specified benchmarks with the different fuzzing
configurations, and its output will be piped back to your terminal.  During this
process, you can observe the runner VMs being created at
<https://pantheon.corp.google.com/compute/instances?project=fuzzer-test-suite>.

After the dispatcher finishes building the benchmarks, it will start to download
and process the corpus snapshots produced by the runners.  At this point, you
can start monitoring the coverage graphs produced by the dispatcher at
<https://storage.googleapis.com/fuzzer-test-suite-public/afl-libfuzzer/index.html>.

When all trials have completed and the dispatcher is finished processing all
snapshots, the dispatcher will automatically shut down, and the pipe to your
terminal will be closed.  When this happens, you'll see an error message similar
to:
```
Connection to 35.197.3.39 closed by remote host.
ERROR: (gcloud.compute.ssh) [/usr/bin/ssh] exited with return code [255].
```
This is expected and should not be a cause for concern.
