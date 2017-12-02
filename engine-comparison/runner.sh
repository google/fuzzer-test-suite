#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on the runner VMs.  Executes several trials of a benchmark and
# uploads corpus snapshots for the dispatcher to pull.

. benchmark.cfg
. parameters.cfg
. fengine.cfg

# WAIT_PERIOD should be longer than the main loop, otherwise a sync cycle will
# be missed
readonly WAIT_PERIOD=20

# rsyncs directories recursively without deleting files at dst.
rsync_no_delete() {
  local src=$1
  local dst=$2
  gsutil -m rsync -rP "${src}" "${dst}"
}

same_dir_tree() {
  local dir1=$1
  local dir2=$2
  diff <(cd "${dir1}" && find . | sort) <(cd "${dir2}" && find . | sort)
}

# Exit status 0 if run limit or time limit has been exceeded
time_run_limits_exceeded() {
  # Only check for AFL.  LibFuzzer case is handled by flags passed to fuzzer.
  if [[ "${FUZZING_ENGINE}" == "afl" ]]; then
    if [[ "${MAX_TOTAL_TIME}" -gt 0 ]]; then
      [[ "${SECONDS}" -gt "${MAX_TOTAL_TIME}" ]] && return 0
    fi
    if [[ "${MAX_RUNS}" -gt 0 ]]; then
      local runs_finished="$(grep execs_done corpus/fuzzer_stats \
        | grep -o -E "[0-9]+")"
      [[ "${runs_finished}" -gt "${MAX_RUNS}" ]] && return 0
    fi
  fi
  return 1
}

conduct_experiment() {
  local exec_cmd=$1
  local trial_num=$2
  local bmark_fengine_dir=$3
  local next_sync=${WAIT_PERIOD}
  local cycle=1
  local sync_dir="gs://fuzzer-test-suite/${EXPERIMENT}/experiment-folders"
  sync_dir="${sync_dir}/${bmark_fengine_dir}/trial-${trial_num}"

  rm -rf corpus last-corpus corpus-archives results
  mkdir -p corpus last-corpus corpus-archives results

  ${exec_cmd} &
  local process_pid=$!
  SECONDS=0  # Builtin that automatically increments every second
  while kill -0 "${process_pid}"; do
    # Ensure that measurements happen every wait period
    local sleep_time=$((next_sync - SECONDS))
    sleep ${sleep_time}

    # Snapshot
    cp -r corpus corpus-copy

    if same_dir_tree corpus-copy last-corpus; then
      # Corpus is unchanged; avoid rsyncing it.
      echo "${cycle}" >> results/unchanged-cycles
    else
      tar -czf "corpus-archives/corpus-archive-${cycle}.tar.gz" corpus-copy
      rsync_no_delete corpus-archives "${sync_dir}/corpus"
    fi
    rsync_no_delete results "${sync_dir}/results"

    # Done with snapshot
    rm -r last-corpus
    mv corpus-copy last-corpus
    rm "corpus-archives/corpus-archive-${cycle}.tar.gz"

    time_run_limits_exceeded && kill -2 "${process_pid}"

    cycle=$((cycle + 1))
    next_sync=$((cycle * WAIT_PERIOD))
    # Skip cycle if need be
    while [[ ${next_sync} -lt ${SECONDS} ]]; do
      echo "${cycle}" >> results/skipped-cycles
      cycle=$((cycle + 1))
      next_sync=$((cycle * WAIT_PERIOD))
    done
  done

  # Sync final corpus
  tar -czf "corpus-archives/corpus-archive-${cycle}.tar.gz" corpus
  rsync_no_delete corpus-archives "${sync_dir}/corpus"

  # Sync final fuzz log
  echo "${exec_cmd}" > command-line.txt
  mv fuzz-0.log command-line.txt crash* leak* timeout* oom* results/
  mv corpus/crashes corpus/hangs corpus/fuzzer_stats results/
  rsync_no_delete results "${sync_dir}/results"
}

main() {
  # This name used to be the name of the file fengine.cfg. It was renamed in the
  # dispatcher, so it was stored as metadata.
  local binary="./${BENCHMARK}-${FUZZING_ENGINE}"
  local metadata_url="http://metadata.google.internal/computeMetadata/v1"
  local fengine_url="${metadata_url}/instance/attributes/fengine"
  local fengine_name="$(curl "${fengine_url}" -H "Metadata-Flavor: Google")"
  local trial_url="${metadata_url}/instance/attributes/trial"
  local trial="$(curl "${trial_url}" -H "Metadata-Flavor: Google")"

  chmod 750 "${binary}"

  if [[ "${FUZZING_ENGINE}" == "afl" ]]; then
    chmod 750 afl-fuzz

    # AFL requires some starter input
    [[ ! -d seeds ]] && mkdir seeds
    [[ ! $(find seeds -type f) ]] && echo > ./seeds/nil_seed
    export AFL_SKIP_CPUFREQ=1

    local exec_cmd="./afl-fuzz ${BINARY_RUNTIME_OPTIONS} -i seeds -o corpus"
    if ls ./*.dict; then
      local dict_path="$(find . -maxdepth 1 -name "*.dict" | head -n 1)"
      exec_cmd="${exec_cmd} -x ${dict_path}@9"
    fi
    exec_cmd="${exec_cmd} -m none -- ${binary}"
  elif [[ "${FUZZING_ENGINE}" == "libfuzzer" || \
    "${FUZZING_ENGINE}" == "fsanitize_fuzzer" ]]; then
    local exec_cmd="${binary} ${BINARY_RUNTIME_OPTIONS}"
    exec_cmd="${exec_cmd} -workers=${JOBS} -jobs=${JOBS} -runs=${MAX_RUNS}"
    exec_cmd="${exec_cmd} -max_total_time=${MAX_TOTAL_TIME}"
    if ls ./*.dict; then
      local dict_path="$(find . -maxdepth 1 -name "*.dict" | head -n 1)"
      exec_cmd="${exec_cmd} -dict=${dict_path}"
    fi
    exec_cmd="${exec_cmd} -print_final_stats=1 -close_fd_mask=3 corpus"
    [[ -d seeds ]] && exec_cmd="${exec_cmd} seeds"
  else
    echo "Error: Unsupported fuzzing engine ${FUZZING_ENGINE}"
    exit 1
  fi

  local bmark_fengine_dir="${BENCHMARK}-${fengine_name}"
  conduct_experiment "${exec_cmd}" "${trial}" "${bmark_fengine_dir}"

  # We're done. Notify dispatcher and delete this runner to save resources.
  touch finished
  local sync_dir="gs://fuzzer-test-suite/${EXPERIMENT}/experiment-folders"
  sync_dir="${sync_dir}/${bmark_fengine_dir}/trial-${trial}"
  gsutil -m mv finished "${sync_dir}/"
  gcloud compute instances delete --zone us-west1-b -q "${INSTANCE_NAME}"
}

main "$@"
