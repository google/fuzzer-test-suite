# A/B Testing Tutorial

## Introduction

In this tutorial, you will learn how to set up and run experiments comparing two
fuzzing configurations on a set of benchmarks.

## Prerequisites

- [Configure a Google Cloud Platform project](../gcpConfig.md) for experiments.

## Set Up the Environment

From the [Compute Engine
Console](https://console.cloud.google.com/compute) for your project, create a
Google Debian GNU/Linux 9 instance, selecting the service account you configured
with Editor permissions and selecting "Allow full access to all Cloud APIs".
SSH to the new instance by clicking the SSH button next to the instance in the
console.

Once you have a shell open on the instance, simply install Git and clone this
repository.
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
This configuration sets `fsanitize_fuzzer` as the fuzzing engine, which tells
the framework to use libFuzzer's default `-fsanitize=fuzzer` flag for coverage
instrumentation.  The second line instructs the testing framework to run
libFuzzer with the `-timeout=25` option.  `-timeout=25` is analogous to AFL's
`-t 25000`.

### Experiment Parameters

Now take a look at the supplied `afl-lf.cfg` file.
```shell
cat FTS/engine-comparison/tutorial/param/afl-lf.cfg
```
This file defines the parameters for our experiment as follows.

- `EXPERIMENT="afl-libfuzzer"` - Names the experiment `afl-libfuzzer`.  This
  determines the URL at which results will be displayed.
- `RUNNERS=2` - 2 runners will be spawned per fuzzer.
- `JOBS=1` - Each fuzzer will run single-threaded.
- `MAX_RUNS=-1` - Trials will not be limited by number of inputs run.
- `MAX_TOTAL_TIME=300` - Trials will end after 300 seconds (5 minutes).

The file also contains parameters specifying the GCP project configuration.
**You should change these parameters to match the project you configured
earlier.**

- `PROJECT="fuzzer-test-suite"` - Replace with your own GCP project ID.
- `CLOUDSDK_COMPUTE_ZONE="us-west1-b"` - Replace with the zone for which you
  configured your GCP project quotas.
- `GSUTIL_BUCKET="gs://fuzzer-test-suite"` - Replace with your own experiment
  bucket.
- `GSUTIL_WEB_BUCKET="gs://fuzzer-test-suite-public"` - Replace with your own
  web report bucket.
- `SERVICE_ACCOUNT="373628893752-compute@developer.gserviceaccount.com"` -
  Replace with the service account you configured with the Editor role.

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
<https://console.cloud.google.com/compute>.

After the dispatcher finishes building the benchmarks, it will start to download
and process the corpus snapshots produced by the runners.  At this point, you
can start monitoring the coverage graphs produced by the dispatcher at
<https://storage.googleapis.com/GSUTIL_WEB_BUCKET/afl-libfuzzer/index.html>.  Be
sure to replace `GSUTIL_WEB_BUCKET` in the URL with the name of your own web
report bucket (omit the `gs://` prefix).

When all runners have finished and the dispatcher is finished processing all
snapshots, the dispatcher will automatically shut down, and the pipe to your
terminal will be closed.  When this happens, you'll see an error message similar
to:
```
Connection to 35.197.3.39 closed by remote host.
ERROR: (gcloud.compute.ssh) [/usr/bin/ssh] exited with return code [255].
```
This is expected and is not a cause for concern.

### FAQs

#### When I try to start an experiment, I get an error message:
```
ERROR: (gcloud.iam.service-accounts.keys.create) RESOURCE_EXHAUSTED: Maximum number of keys on account reached
```

You need to
[delete unused keys](https://console.cloud.google.com/iam-admin/serviceaccounts)
from your service account.  Every time you run an experiment, the framework
checks for the file `./autogen-PRIVATE-key.json`.  If the file doesn't exist,
the framework generates a new key and saves it in that file. Over time, you may
hit the 10 key limit for your service account.  You can prevent this from
happening by saving your `autogen-PRIVATE-key.json` file and reusing it for
future experiments.
