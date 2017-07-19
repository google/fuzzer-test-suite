# A/B testing for fuzzing engines

This work-in-progress document collects ideas about
[A/B testing](https://en.wikipedia.org/wiki/A/B_testing) for fuzzing engines

## Tool Name
(propose names)
* fuzz-comparator? 
* fuzzab? 

## A/B Report

The end goal of the tool is to produce an html report that compares `K` fuzzing engines on `B` different benchmarks executed independently `N` times each on a `J` cores. 

## Comparing different fuzzing engines
* libFuzzer vs other guided engines: AFL, honggfuzz, etc
* libFuzzer vs mutation engines, e.g. Radamsa 

## Comparing different modes of libFuzzer
* -use_counters=1 vs =0
* -use_value_profile=1 vs =0
* -shrink=1 vs =0
* edge coverage vs bb coverage instrumentation
