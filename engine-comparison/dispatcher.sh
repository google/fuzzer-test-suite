#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on the dispatcher.  Builds each benchmark with each fuzzing
# configuration, spawns a runner VM for each benchmark-fuzzer combo, and then
# records coverage data received from the runner VMs.

. "$(dirname "$0")/../common.sh"
. "${SCRIPT_DIR}/common-harness.sh"

# rsyncs directories recursively, deleting files at dst.
rsync_delete() {
  local src=$1
  local dst=$2
  gsutil -m rsync -rd "${src}" "${dst}"
}

# Run the specified command in a shell with no environment variables set.
exec_in_clean_env() {
  local cmd=$1
  local set_path_cmd="export PATH=/usr/bin:/bin:/usr/local/bin"
  env -i bash -c "${set_path_cmd} && ${cmd}"
}

# Given a config file specifying a fuzzing engine, download that fuzzing engine
download_engine() {
  local fengine_config=$1
  [[ ! -e "${fengine_config}" ]] && \
    echo "Error: download_engine() couldn't find ${fengine_config}" && \
    exit 1
  local fengine_name="$(basename "${fengine_config}")"
  local fengine_dir="${WORK}/fengine-builds/${fengine_name}"

  echo "Creating fuzzing engine: ${fengine_config}"
  rm -rf "${fengine_dir}"
  mkdir "${fengine_dir}"

  . "${fengine_config}"
  case "${FUZZING_ENGINE}" in
    libfuzzer)
      if [[ ! -d "${LIBFUZZER_SRC}/standalone" ]]; then
        echo "Checking out libFuzzer"
        svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer \
          "${WORK}/Fuzzer"
        export LIBFUZZER_SRC="${WORK}/Fuzzer"
      fi
      ;;
    afl)
      if [[ ! -d "${LIBFUZZER_SRC}/afl" ]]; then
        mkdir -p "${LIBFUZZER_SRC}/afl"
        svn co \
          http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer/afl \
          "${LIBFUZZER_SRC}/afl"
      fi
      echo "Building AFL"
      pushd "${WORK}/fengine-builds"
      wget http://lcamtuf.coredump.cx/afl/releases/afl-latest.tgz
      tar xf afl-latest.tgz -C "${fengine_dir}" --strip-components=1
      (cd "${fengine_dir}" && AFL_USE_ASAN=1 make clean all)
      rm afl-latest.tgz
      popd
      export AFL_SRC="${fengine_dir}"
      ;;
    fsanitize_fuzzer) ;;
    *)
      echo "Error: Unknown fuzzing engine: ${FUZZING_ENGINE}"
      exit 1
      ;;
  esac
}

build_benchmark() {
  local benchmark=$1
  local fengine_config=$2
  local output_dirname=$3

  local building_dir="${WORK}/build/${output_dirname}"
  echo "Building in ${building_dir}"
  rm -rf "${building_dir}"
  mkdir "${building_dir}"

  local build_cmd=". ${fengine_config} && ${WORK}/FTS/${benchmark}/build.sh"
  (cd "${building_dir}" && exec_in_clean_env "${build_cmd}")

  export SEND_DIR="${WORK}/send/${output_dirname}"
  rm -rf "${SEND_DIR}"
  mkdir "${SEND_DIR}"

  # Copy the executable and delete build directory
  cp "${building_dir}/${benchmark}-${FUZZING_ENGINE}" "${SEND_DIR}/"
  rm -rf "${building_dir}"

  cp "${WORK}/FTS/engine-comparison/Dockerfile-runner" "${SEND_DIR}/Dockerfile"
  cp "${WORK}/FTS/engine-comparison/runner.sh" "${SEND_DIR}/"
  cp "${WORK}/FTS/engine-comparison/config/parameters.cfg" "${SEND_DIR}/"
  cp "${fengine_config}" "${SEND_DIR}/fengine.cfg"

  echo "BENCHMARK=${benchmark}" > "${SEND_DIR}/benchmark.cfg"

  if [[ -d "${WORK}/FTS/${benchmark}/seeds" ]]; then
    cp -r "${WORK}/FTS/${benchmark}/seeds" "${SEND_DIR}"
  fi
  if [[ "${FUZZING_ENGINE}" == "afl" ]]; then
    cp "${AFL_SRC}/afl-fuzz" "${SEND_DIR}"
  fi
}

# Starts a runner VM
create_or_start_runner() {
  local instance_name=$1
  local benchmark=$2
  local fengine_name=$3
  create_or_start "${instance_name}" \
    "benchmark=${benchmark},fengine=${fengine_name}" \
    "startup-script=${WORK}/FTS/engine-comparison/startup-runner.sh"
}

# Top-level function to handle the initialization of a single runner VM. Builds
# the binary, assembles a folder with configs and seeds, and starts the VM.
handle_benchmark() {
  local benchmark=$1
  local fengine_config=$2
  local fengine_name="$(basename "${fengine_config}")"
  local bmark_with_fengine="${benchmark}-with-${fengine_name}"
  build_benchmark "${benchmark}" "${fengine_config}" "${bmark_with_fengine}"
  rsync_delete "${SEND_DIR}" \
    "${GSUTIL_BUCKET}/binary-folders/${bmark_with_fengine}"
  # GCloud instance names must match the following regular expression:
  # '[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?'
  local instance_name="$(echo "fts-runner-${bmark_with_fengine}" | \
    tr '[:upper:]' '[:lower:]' | tr -d '.')"
  create_or_start_runner "${instance_name}" "${benchmark}" "${fengine_name}"
}

# Make a "plain" coverage build for a benchmark
make_measurer() {
  local benchmark=$1
  local building_dir="${WORK}/coverage-builds/${benchmark}"
  mkdir -p "${building_dir}"
  (cd "${building_dir}" && exec_in_clean_env \
    "FUZZING_ENGINE=coverage ${WORK}/FTS/${benchmark}/build.sh")
  mv "${building_dir}/${benchmark}-coverage" "${WORK}/coverage-binaries/"
  rm -rf "${building_dir}"
}

# Process a corpus, generate a human readable report, send the report to gsutil
# Processing includes: decompress, use sancov.py, etc
measure_coverage() {
  local fengine_config=$1
  local benchmark=$2
  local fengine_name="$(basename "${fengine_config}")"
  local bmark_fengine_dir="${benchmark}/${fengine_name}"
  local corpus_dir="${WORK}/measurement-folders/${bmark_fengine_dir}/corpus"
  local sancov_dir="${WORK}/measurement-folders/${bmark_fengine_dir}/sancovs"
  local rep_base_dir="${WORK}/measurement-folders/${bmark_fengine_dir}/reports"
  local exp_base_dir="${WORK}/experiment-folders/${benchmark}-${fengine_name}"

  rm -rf "${corpus_dir}" "${sancov_dir}"
  mkdir -p "${corpus_dir}" "${sancov_dir}" "${rep_base_dir}"

  # Recall which trial
  if [[ -f "${rep_base_dir}/latest-trial" ]]; then
    . "${rep_base_dir}/latest-trial"
  else
    LATEST_TRIAL=0
  fi

  # Append trial directories
  local experiment_dir="${exp_base_dir}/trial-${LATEST_TRIAL}"
  local report_dir="${rep_base_dir}/trial-${LATEST_TRIAL}"
  mkdir -p "${report_dir}"

  # Use the corpus-archive directly succeeding the last one to be processed
  if [[ -f "${report_dir}/latest-cycle" ]]; then
    . "${report_dir}/latest-cycle"
  else
    LATEST_CYCLE=0
  fi

  # Decide which cycle to report on
  # First, check if the runner documented that it skipped any cycles
  local this_cycle=$((LATEST_CYCLE + 1))
  while grep "^${this_cycle}$" "${experiment_dir}/results/skipped-cycles"; do
    this_cycle=$((this_cycle + 1))
  done

  if [[ ! -f \
    "${experiment_dir}/corpus/corpus-archive-${this_cycle}.tar.gz" ]]; then
    # We don't have a new corpus archive.  Determine why.
    if grep "^${this_cycle}$" "${experiment_dir}/results/unchanged-cycles"; then
      # No corpus archive because the corpus hasn't changed.
      # Copy stats from last cycle.
      local coverage_line="$(tail -n1 "${report_dir}/coverage-graph.csv")"
      local corpus_size_line="$(tail -n1 "${report_dir}/corpus-size-graph.csv")"
      local corpus_elems_line="$(tail -n1 \
        "${report_dir}/corpus-elems-graph.csv")"
      local coverage="${coverage_line##*,}"
      local corpus_size="${corpus_size_line##*,}"
      local corpus_elems="${corpus_elems_line##*,}"
    else
      echo "On cycle ${this_cycle}, no new corpus found for:"
      echo "  benchmark: ${benchmark}"
      echo "  fengine: ${fengine_name}"
      echo "  trial: ${LATEST_TRIAL}"

      if [[ -d "${exp_base_dir}/trial-$((LATEST_TRIAL + 1))" ]]; then
        # No corpus archive because we've already analyzed all corpora for this
        # trial.
        echo "LATEST_TRIAL=$((LATEST_TRIAL + 1))" > \
          "${rep_base_dir}/latest-trial"
      fi
      return
    fi
  else
    # We have a new corpus archive.  Collect stats on it.
    # Extract corpus
    (cd "${corpus_dir}" &&
      tar -xf "${experiment_dir}/corpus/corpus-archive-${this_cycle}.tar.gz" \
        --strip-components=1)

    # Generate sancov
    (cd "${sancov_dir}" &&
      UBSAN_OPTIONS=coverage=1 \
        "${WORK}/coverage-binaries/${benchmark}-coverage" \
        $(find "${corpus_dir}" -type f))

    local coverage="$("${WORK}/coverage-builds/sancov.py" print \
      "${sancov_dir}/*" | wc -w)"
    local corpus_size="$(wc -c $(find "${corpus_dir}" -maxdepth 1 -type f) \
      | tail --lines=1 \
      | grep -o "[0-9]*")"
    local corpus_elems="$(find "${corpus_dir}" -maxdepth 1 -type f | wc -l)"
  fi

  # Finish generating human readable report
  echo "${this_cycle},${coverage}" >> "${report_dir}/coverage-graph.csv"
  echo "${this_cycle},${corpus_size}" >> "${report_dir}/corpus-size-graph.csv"
  echo "${this_cycle},${corpus_elems}" >> "${report_dir}/corpus-elems-graph.csv"

  echo "LATEST_CYCLE=${this_cycle}" > "${report_dir}/latest-cycle"
  rsync_delete "${rep_base_dir}" "${GSUTIL_BUCKET}/reports/${bmark_fengine_dir}"
}

main() {
  mkdir "${WORK}/fengine-builds"
  mkdir "${WORK}/build"
  mkdir "${WORK}/send"

  # Stripped down equivalent of "gcloud init"
  gcloud auth activate-service-account "${SERVICE_ACCOUNT}" \
    --key-file="${WORK}/FTS/engine-comparison/config/autogen-PRIVATE-key.json"
  gcloud config set project fuzzer-test-suite

  # This config file defines $BMARKS
  . "${WORK}/FTS/engine-comparison/config/bmarks.cfg"
  # Now define $BENCHMARKS. Encode aliases here
  case "${BMARKS}" in
    all)
      while read benchmark; do
        BENCHMARKS="${BENCHMARKS} $(basename "$(dirname "${benchmark}")")"
      done < <(find "${SCRIPT_DIR}/.." -name "build.sh")
      ;;
    small) BENCHMARKS="c-ares-CVE-2016-5180 re2-2014-12-09" ;;
    none) BENCHMARKS="" ;;
    three) BENCHMARKS="libssh-2017-1272 json-2017-02-12 proj4-2017-08-14" ;;
    *) BENCHMARKS="$(echo "${BMARKS}" | tr ',' ' ')" ;;
  esac
  readonly BENCHMARKS

  # Reset google cloud results before doing experiments
  gsutil -m rm -r "${GSUTIL_BUCKET}/experiment-folders" \
    "${GSUTIL_BUCKET}/reports"

  # Outermost loops
  while read fengine_config; do
    download_engine "${fengine_config}"
    for benchmark in ${BENCHMARKS}; do
      handle_benchmark "${benchmark}" "${fengine_config}" &
    done
  done < <(find "${WORK}/fengine-configs" -type f)
  wait

  # TODO here: reset fengine-config env vars (?)
  ############# DONE building
  rm -rf "${WORK}/send" "${WORK}"/build
  ############# NOW wait for experiment results

  mkdir -p "${WORK}/coverage-builds"

  # Choice of preference: sancov.py over sancov CLI
  if [[ ! -f "${WORK}/coverage-builds/sancov.py" ]]; then
    pushd "${WORK}/coverage-builds"
    local compiler_rt_url="http://llvm.org/svn/llvm-project/compiler-rt/trunk/"
    local sancov_py_path="lib/sanitizer_common/scripts/sancov.py"
    wget "${compiler_rt_url}${sancov_py_path}"
    chmod 750 "sancov.py"
    popd
  fi

  # Download standalone main for coverage builds.
  if [[ ! -d "${LIBFUZZER_SRC}/standalone" ]]; then
    echo "Checking out libFuzzer"
    export LIBFUZZER_SRC="${WORK}/Fuzzer"
    svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer \
      "${LIBFUZZER_SRC}"
  fi

  # Do coverage builds
  mkdir -p "${WORK}/coverage-binaries"
  for benchmark in ${BENCHMARKS}; do
    make_measurer "${benchmark}" &
  done
  wait

  set -x

  mkdir -p "${WORK}/experiment-folders"
  mkdir -p "${WORK}/measurement-folders"

  # wait_period defines how frequently the dispatcher generates new reports for
  # every benchmark with every fengine. For a large number of runner VMs,
  # wait_period in dispatcher.sh can be smaller than it is in runner.sh
  local wait_period=10
  local next_sync=${SECONDS}
  # TODO: better "while" condition?
  # Maybe not: just end dispatcher VM when done
  while true; do
    local sleep_time=$((next_sync - SECONDS))
    if [[ ${sleep_time} -gt 0 ]]; then
      sleep ${sleep_time}
    else
      next_sync=${SECONDS}
    fi

    # Prevent calling measure_coverage before runner VM begins
    if gsutil ls "${GSUTIL_BUCKET}" | grep "experiment-folders"; then
      rsync_delete "${GSUTIL_BUCKET}/experiment-folders" \
        "${WORK}/experiment-folders"
      for benchmark in ${BENCHMARKS}; do
        while read fengine_config; do
          measure_coverage "${fengine_config}" "${benchmark}" &
        done < <(find "${WORK}/fengine-configs" -type f)
      done
      wait
    fi

    next_sync=$((next_sync + wait_period))
  done
}

main "$@"
