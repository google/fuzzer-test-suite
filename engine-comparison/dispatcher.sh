#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on the dispatcher.  Builds each benchmark with each fuzzing
# configuration, spawns a runner VM for each benchmark-fuzzer combo, and then
# records coverage data received from the runner VMs.

. "$(dirname "$0")/../common.sh"
. "${SCRIPT_DIR}/common-harness.sh"

# Runs the specified gsutil command with its own state directory to avoid race
# conditions.
p_gsutil() {
  local state_dir="/tmp/gsutil.${BASHPID}"
  gsutil -m -o "GSUtil:state_dir=${state_dir}" "$@"
  local ret=$?
  rm -rf "${state_dir}"
  return ${ret}
}

# rsyncs directories recursively, deleting files at dst.
rsync_delete() {
  local src=$1
  local dst=$2
  p_gsutil rsync -rd "${src}" "${dst}"
}

# Run the specified command in a shell with no environment variables set.
exec_in_clean_env() {
  local cmd=$1
  local set_path_cmd="export PATH=/usr/bin:/bin:/usr/local/bin"
  env -i bash -c "${set_path_cmd} && ${cmd}"
}

get_afl() {
  echo "Building AFL"
  wget http://lcamtuf.coredump.cx/afl/releases/afl-latest.tgz
  tar xf afl-latest.tgz --strip-components=1
  rm afl-latest.tgz
  make clean all
}

# Creates index.html in the specified directory with links to graphs for each
# benchmark and fuzzing configuration.
emit_index_page() {
  local web_dir=$1
  local dst="${web_dir}/index.html"
  local url_prefix="/fuzzer-test-suite-public/webpage-graphs"
  {
    echo "<!DOCTYPE html>"
    echo "<meta charset=\"utf-8\">"
    echo "<title>A/B Experiment Results</title>"
    echo "<body><h2>A/B Experiment Results</h2><ul>"
    while read bm_path; do
      local bm="$(basename "${bm_path}")"
      local bm_url="${url_prefix}/${bm}/comparison-charts.html"
      echo "<li><a href=\"${bm_url}\">${bm}</a>"
      while read fengine_path; do
        local fengine="$(basename "${fengine_path}")"
        local fengine_url="${url_prefix}/${bm}/${fengine}/fengine-charts.html"
        echo "<a href=\"${fengine_url}\">[${fengine}]</a>"
      done < <(find "${bm_path}" -maxdepth 1 -mindepth 1 -type d)
      echo "</li>"
    done < <(find "${web_dir}" -maxdepth 1 -mindepth 1 -type d | sort)
    echo "</ul></body>"
  } > "${dst}"
}

# Updates web graphs in an infinite loop
live_graphing_loop() {
  local report_gen_dir="${WORK}/FTS/engine-comparison/report-gen"
  local web_dir="${WORK}/reports"
  rm -rf "${web_dir}" && mkdir "${web_dir}"

  # Wait for main loop to start generating reports
  while ! p_gsutil ls "${GSUTIL_BUCKET}/reports" &> /dev/null; do sleep 5; done

  local wait_period=10
  local next_sync=${SECONDS}
  while true; do
    local sleep_time=$((next_sync - SECONDS))
    if [[ ${sleep_time} -gt 0 ]]; then
      sleep ${sleep_time}
    else
      next_sync=${SECONDS}
    fi

    rsync_delete "${GSUTIL_BUCKET}/reports" "${web_dir}" &> /dev/null
    (cd "${WORK}" && go run "${report_gen_dir}/generate-report.go")

    while read bm; do
      cp "${report_gen_dir}/comparison-charts.html" "${bm}/"
      find "${bm}" -maxdepth 1 -mindepth 1 -type d -exec \
        cp "${report_gen_dir}/fengine-charts.html" {}/ \;
    done < <(find "${web_dir}" -maxdepth 1 -mindepth 1 -type d)

    emit_index_page "${web_dir}"

    # Set object metadata to prevent caching and always display latest graphs.
    p_gsutil -h "Cache-Control:public,max-age=0,no-transform" rsync -rd \
      "${web_dir}" "${GSUTIL_PUBLIC_BUCKET}/webpage-graphs" &> /dev/null

    next_sync=$((next_sync + wait_period))
  done
}

# Given a config file specifying a fuzzing engine, download that fuzzing engine
download_engine() {
  local fengine_config=$1
  [[ ! -e "${fengine_config}" ]] && \
    echo "Error: download_engine() couldn't find ${fengine_config}" && \
    exit 1

  . "${fengine_config}"
  case "${FUZZING_ENGINE}" in
    libfuzzer)
      if [[ ! -d "${LIBFUZZER_SRC}/standalone" ]]; then
        echo "Checking out libFuzzer"
        svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer \
          "${LIBFUZZER_SRC}"
      fi
      ;;
    afl)
      if [[ ! -d "${LIBFUZZER_SRC}/afl" ]]; then
        mkdir -p "${LIBFUZZER_SRC}/afl"
        svn co \
          http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer/afl \
          "${LIBFUZZER_SRC}/afl"
      fi
      if [[ ! -f "${AFL_SRC}/afl-fuzz" ]]; then
        mkdir -p "${AFL_SRC}"
        (cd "${AFL_SRC}" && get_afl)
      fi
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

  local bmark_dir="${WORK}/FTS/${benchmark}"
  [[ -d "${bmark_dir}/seeds" ]] && cp -r "${bmark_dir}/seeds" "${SEND_DIR}"
  [[ -d "${bmark_dir}/runtime" ]] && cp -r "${bmark_dir}/runtime" "${SEND_DIR}"

  [[ "${FUZZING_ENGINE}" == "afl" ]] && cp "${AFL_SRC}/afl-fuzz" "${SEND_DIR}"
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
  [[ -d "${building_dir}/runtime" ]] && \
    cp -r "${building_dir}"/runtime/* "${WORK}/coverage-binaries/runtime/"
  rm -rf "${building_dir}"
}

extract_corpus() {
  local corpus_tgz=$1
  tar -xf "${corpus_tgz}" --strip-components=1
  if [[ -d queue ]]; then
    # This is an AFL corpus.  Extract inputs from queue directory.
    find . -mindepth 1 -maxdepth 1 ! -name queue -exec rm -rf {} +
    mv queue/* .
    rm -rf queue
  fi
}

# Runs a coverage binary on the inputs present in corpus2 but not corpus1.
run_cov_new_inputs() {
  local coverage_binary=$1
  local corpus1=$2
  local corpus2=$3
  UBSAN_OPTIONS=coverage=1 "${coverage_binary}" \
    $(comm -13 <(ls "${corpus1}") <(ls "${corpus2}") \
      | while read line; do echo "${corpus2}/${line}"; done)
}

# Process a corpus, generate a human readable report, send the report to gsutil
# Processing includes: decompress, use sancov.py, etc
measure_coverage() {
  local fengine_config=$1
  local benchmark=$2
  local fengine_name="$(basename "${fengine_config}")"
  local bmark_fengine_dir="${benchmark}/${fengine_name}"
  local measurement_dir="${WORK}/measurement-folders/${bmark_fengine_dir}"
  local corpus_dir="${measurement_dir}/corpus"
  local prev_corpus_dir="${measurement_dir}/last-corpus"
  local sancov_dir="${measurement_dir}/sancovs"
  local rep_base_dir="${measurement_dir}/reports"
  local exp_base_dir="${WORK}/experiment-folders/${benchmark}-${fengine_name}"

  rm -rf "${corpus_dir}" "${sancov_dir}"
  mkdir -p "${corpus_dir}" "${sancov_dir}" "${rep_base_dir}" \
    "${prev_corpus_dir}"

  # Recall which trial
  if [[ -f "${rep_base_dir}/latest-trial" ]]; then
    . "${rep_base_dir}/latest-trial"
  else
    LATEST_TRIAL=0
  fi

  # Append trial directories
  local experiment_dir="${exp_base_dir}/trial-${LATEST_TRIAL}"
  local report_dir="${rep_base_dir}/trial-${LATEST_TRIAL}"
  local covered_pcs_file="${report_dir}/covered-pcs.txt"
  mkdir -p "${report_dir}"
  [[ -f "${covered_pcs_file}" ]] || touch "${covered_pcs_file}"

  # Use the corpus-archive directly succeeding the last one to be processed
  if [[ -f "${report_dir}/latest-cycle" ]]; then
    . "${report_dir}/latest-cycle"
  else
    LATEST_CYCLE=0
  fi

  # Decide which cycle to report on
  # First, check if the runner documented that it skipped any cycles
  local this_cycle=$((LATEST_CYCLE + 1))
  while grep "^${this_cycle}$" "${experiment_dir}/results/skipped-cycles" \
    &> /dev/null; do
    # Record empty stats for proper data aggregation later.
    echo "${this_cycle}," >> "${report_dir}/coverage-graph.csv"
    echo "${this_cycle}," >> "${report_dir}/corpus-size-graph.csv"
    echo "${this_cycle}," >> "${report_dir}/corpus-elems-graph.csv"
    this_cycle=$((this_cycle + 1))
  done

  if [[ ! -f \
    "${experiment_dir}/corpus/corpus-archive-${this_cycle}.tar.gz" ]]; then
    # We don't have a new corpus archive.  Determine why.
    if grep "^${this_cycle}$" "${experiment_dir}/results/unchanged-cycles" \
      &> /dev/null; then
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
      if [[ -d "${exp_base_dir}/trial-$((LATEST_TRIAL + 1))" ]]; then
        # No corpus archive because we've already analyzed all corpora for this
        # trial.
        echo "LATEST_TRIAL=$((LATEST_TRIAL + 1))" > \
          "${rep_base_dir}/latest-trial"
        rm -rf "${prev_corpus_dir}"
      fi
      return
    fi
  else
    # We have a new corpus archive.  Collect stats on it.
    # Extract corpus
    echo "Corpus #${this_cycle} found for:"
    echo "  benchmark: ${benchmark}"
    echo "  fengine: ${fengine_name}"
    echo "  trial: ${LATEST_TRIAL}"

    (cd "${corpus_dir}" && extract_corpus \
      "${experiment_dir}/corpus/corpus-archive-${this_cycle}.tar.gz")

    # Generate coverage information for new inputs only.
    cp -r "${WORK}/coverage-binaries/runtime" "${sancov_dir}/"
    (cd "${sancov_dir}" && \
      run_cov_new_inputs "${WORK}/coverage-binaries/${benchmark}-coverage" \
        "${prev_corpus_dir}" "${corpus_dir}")
    rm -r "${sancov_dir}/runtime"

    # Get PCs covered by new inputs and merge with the previous list.
    "${WORK}/coverage-builds/sancov.py" print "${sancov_dir}/*" 2>/dev/null \
      | sort -o "${covered_pcs_file}" -m -u - "${covered_pcs_file}"

    local coverage="$(wc -w < "${covered_pcs_file}")"
    local corpus_size="$(wc -c $(find "${corpus_dir}" -maxdepth 1 -type f) \
      | tail --lines=1 \
      | grep -o "[0-9]*")"
    local corpus_elems="$(find "${corpus_dir}" -maxdepth 1 -type f | wc -l)"

    # Save corpus for comparison next cycle
    rm -rf "${prev_corpus_dir}"
    mv "${corpus_dir}" "${prev_corpus_dir}"

    # Move this corpus archive to the processed folder so that rsync doesn't
    # need to check it anymore.
    local bmark_trial="${benchmark}-${fengine_name}/trial-${LATEST_TRIAL}"
    local src_archive="${GSUTIL_BUCKET}/experiment-folders/${bmark_trial}"
    src_archive="${src_archive}/corpus/corpus-archive-${this_cycle}.tar.gz"
    local dst_archive="${GSUTIL_BUCKET}/processed-folders/${bmark_trial}"
    dst_archive="${dst_archive}/corpus-archive-${this_cycle}.tar.gz"
    p_gsutil mv "${src_archive}" "${dst_archive}"
  fi

  # Finish generating human readable report
  echo "${this_cycle},${coverage}" >> "${report_dir}/coverage-graph.csv"
  echo "${this_cycle},${corpus_size}" >> "${report_dir}/corpus-size-graph.csv"
  echo "${this_cycle},${corpus_elems}" >> "${report_dir}/corpus-elems-graph.csv"

  echo "LATEST_CYCLE=${this_cycle}" > "${report_dir}/latest-cycle"
  rsync_delete "${rep_base_dir}" "${GSUTIL_BUCKET}/reports/${bmark_fengine_dir}"
}

main() {
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
  p_gsutil rm -r "${GSUTIL_BUCKET}/experiment-folders" \
    "${GSUTIL_BUCKET}/reports"

  # Outermost loops
  while read fengine_config; do
    download_engine "${fengine_config}"
    for benchmark in ${BENCHMARKS}; do
      handle_benchmark "${benchmark}" "${fengine_config}" &
    done
  done < <(find "${WORK}/fengine-configs" -type f)
  wait

  ############# DONE building
  rm -rf "${WORK}/send" "${WORK}/build"
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
  mkdir -p "${WORK}/coverage-binaries/runtime"
  for benchmark in ${BENCHMARKS}; do
    make_measurer "${benchmark}" &
  done
  wait

  mkdir -p "${WORK}/experiment-folders"
  mkdir -p "${WORK}/measurement-folders"

  p_gsutil rm -r "${GSUTIL_BUCKET}/processed-folders"

  # Start detached process to update graphs
  live_graphing_loop & disown

  # wait_period defines how frequently the dispatcher generates new reports for
  # every benchmark with every fengine. For a large number of runner VMs,
  # wait_period in dispatcher.sh can be smaller than it is in runner.sh
  local wait_period=10
  local next_sync=${SECONDS}
  local sync_num=1
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
    if p_gsutil ls "${GSUTIL_BUCKET}" | grep "experiment-folders" > /dev/null;
    then
      echo "Doing sync #${sync_num}..."
      rsync_delete "${GSUTIL_BUCKET}/experiment-folders" \
        "${WORK}/experiment-folders"
      for benchmark in ${BENCHMARKS}; do
        while read fengine_config; do
          measure_coverage "${fengine_config}" "${benchmark}" &
        done < <(find "${WORK}/fengine-configs" -type f)
      done
      wait
      sync_num=$((sync_num + 1))
    fi

    next_sync=$((next_sync + wait_period))
  done
}

main "$@"
