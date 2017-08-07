# A/B testing for fuzzing engines

This work-in-progress document collects ideas about
[A/B testing](https://en.wikipedia.org/wiki/A/B_testing) for fuzzing engines

## A/B Report

The end goal of the tool is to produce an html report that compares `K` fuzzing engines on `B` different benchmarks executed independently `N` times each on `J` cores. 

The top-level report should be an html file with a set of iframes, one per each benchmark. 

The report for each benchmark should contain
* coverage/time plot
* whether a bug was found
* number of iterations, corpus size (in files and bytes)
* coverage diff (what lines of code were found by some, but not all of `B` engines)

## Execution
The tool should support execution on 
* local machine
* GCE


### Runners and Dispattcher 
The tool spawns `K*B*N` **runner** VMs with `J` cores each and a single (multi-core) **dispatcher** VM. 

* Dispatcher builds `K*B` fuzzer binaries and spawns runners.
* Runners run a benchmark and periodically syncs the resulting corpus to a shared disk.
* Dispatcher periodically syncs all corpora and stats from runners and updates the report
* The top-level script periodically syncs the report from the dispatcher to local disk.

### GCE
A GCS bucket is used as a shared disk, located at `gs://fuzzer-test-suite`. This will be used by the service account to send files between multiple VMs, specifically the dispatcher VM and all runners.
### Local
A local disk is used

### Docker
Docker is used to provide the required dependencies in both the runners and the dispatcher. The startup scripts for VMs will do no more than first `gcloud pull docker image` and then `docker run`.
