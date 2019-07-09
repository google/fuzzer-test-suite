#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on the dispatcher.  Builds each benchmark with each fuzzing
# configuration, spawns a runner VM for each benchmark-fuzzer combo, and then
# records coverage data received from the runner VMs.

. "$(dirname "$0")/../common.sh"
. "${SCRIPT_DIR}/common-harness.sh"
. "${WORK}/FTS/engine-comparison/config/parameters.cfg"

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
  local benchmarks=$1
  local web_dir=$2
  local dst="${web_dir}/index.html"
  {
    echo "<ul><li>$(date)</li>"
    echo "<li>Clang revision: ${CLANG_REVISION}</li>"
    [[ -n "${AFL_REVISION}" ]] && echo "<li>AFL revision: ${AFL_REVISION}</li>"
    [[ -n "${LIBFUZZER_REVISION}" ]] && \
      echo "<li>libFuzzer revision: ${LIBFUZZER_REVISION}</li>"
    while read fengine_config; do
      echo "<li><a href=\"${fengine_config}\">${fengine_config}</a></li>"
    done < <(ls "${WORK}/fengine-configs")
    echo "</ul>"

    echo "Graphing Mode:"
    local input_prefix="<input type=\"radio\" name=\"mode\""
    echo "${input_prefix} id=\"allMode\" value=\"all\" checked>All"
    echo "${input_prefix} id=\"averageMode\" value=\"average\">Average"
    echo "${input_prefix} id=\"maxMode\" value=\"max\">Max"

    echo "<table><tr>"
    echo "<th></th>"
    echo "<th>Coverage</th>"
    echo "<th>Corpus Size</th>"
    echo "<th>Corpus Elements</th></tr>"
    while read bm; do
      echo "<tr><th>${bm}</th>"
      local span_prefix="<td><span class=\"chart\" id=\"${bm}-"
      local span_suffix="\" style=\"display: inline-block\"></span></td>"
      echo "${span_prefix}0${span_suffix}"
      echo "${span_prefix}1${span_suffix}"
      echo "${span_prefix}2${span_suffix}"
      echo "</tr>"
    done < <(echo "${benchmarks}" | tr " " "\n" | grep . | sort)
    echo "</table></body>"
  } >> "${dst}"
}

# Updates web graphs in an infinite loop
live_graphing_loop() {
  local benchmarks=$1
  local report_gen_dir="${WORK}/FTS/engine-comparison/report-gen"
  local web_dir="${WORK}/reports"
  rm -rf "${web_dir}" && mkdir "${web_dir}"
  p_gsutil rm -r "${WEB_BUCKET}"

  # Wait for main loop to start generating reports
  while ! p_gsutil ls "${EXP_BUCKET}/reports" &> /dev/null; do sleep 5; done

  # Give this loop priority for more up-to-date web reports.
  renice -n -10 ${BASHPID}
  ionice -n 0 -p ${BASHPID}

  local wait_period=10
  local next_sync=${SECONDS}
  while true; do
    local sleep_time=$((next_sync - SECONDS))
    if [[ ${sleep_time} -gt 0 ]]; then
      sleep ${sleep_time}
    else
      next_sync=${SECONDS}
    fi

    rsync_delete "${EXP_BUCKET}/reports" "${web_dir}" &> /dev/null
    (cd "${WORK}" && go run "${report_gen_dir}/generate-report.go")

    cp "${report_gen_dir}/base.html" "${web_dir}/index.html"
    cp "${WORK}"/fengine-configs/* "${web_dir}/"
    emit_index_page "${benchmarks}" "${web_dir}"

    # Set object metadata to prevent caching and always display latest graphs.
    p_gsutil -h "Cache-Control:public,max-age=0,no-transform" rsync -r \
      "${web_dir}" "${WEB_BUCKET}" &> /dev/null

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
    honggfuzz)
      if [[ ! -d "${HONGGFUZZ_SRC}/" ]]; then
        echo "Checking out honggfuzz"
        git clone https://github.com/google/honggfuzz.git "${HONGGFUZZ_SRC}"
        # Unset CC, CXX and CFLAGS so we don't try to compile honggfuzz
        # with honggfuzz-clang (which common.sh sets CC to)
        echo "Building honggfuzz"
        (cd "${HONGGFUZZ_SRC}" && env -u CC -u CXX -u CFLAGS -u CXXFLAGS make)
      fi
      ;;
    libfuzzer)
      if [[ ! -d "${LIBFUZZER_SRC}/standalone" ]]; then
        echo "Checking out libFuzzer"
        export LIBFUZZER_REVISION="$( \
          svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk/lib/fuzzer \
          "${LIBFUZZER_SRC}" \
          | grep "Checked out revision" \
          | grep -o "[0-9]*")"
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
        export AFL_REVISION="$("${AFL_SRC}/afl-fuzz" \
          | grep "afl-fuzz.*by" \
          | cut -d " " -f 2 \
          | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")"
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
  local building_dir=$3

  echo "Building in ${building_dir}"
  rm -rf "${building_dir}"
  mkdir "${building_dir}"

  local build_cmd=". ${fengine_config} && ${WORK}/FTS/${benchmark}/build.sh"
  (cd "${building_dir}" && exec_in_clean_env "${build_cmd}")
}

package_benchmark_fuzzer() {
  local benchmark=$1
  local fuzzer_name=$2
  local fengine_config=$3
  local building_dir=$4
  local send_dir=$5
  local fuzzer_suffix="${fuzzer_name#${benchmark}-${FUZZING_ENGINE}}"

  rm -rf "${send_dir}"
  mkdir "${send_dir}"

  cp "${building_dir}/${fuzzer_name}" \
    "${send_dir}/${benchmark}${fuzzer_suffix}-${FUZZING_ENGINE}"
  cp "${WORK}/FTS/engine-comparison/runner.sh" "${send_dir}/"
  cp "${WORK}/FTS/engine-comparison/config/parameters.cfg" "${send_dir}/"
  cp "${fengine_config}" "${send_dir}/fengine.cfg"

  echo "BENCHMARK=${benchmark}${fuzzer_suffix}" > "${send_dir}/benchmark.cfg"

  local bmark_dir="${WORK}/FTS/${benchmark}"
  [[ -d "${bmark_dir}/seeds" ]] && cp -r "${bmark_dir}/seeds" "${send_dir}"
  [[ -d "${building_dir}/seeds" ]] && cp -r "${building_dir}/seeds" \
    "${send_dir}"
  [[ -d "${building_dir}/seeds${fuzzer_suffix}" ]] && \
    cp -r "${building_dir}/seeds${fuzzer_suffix}" "${send_dir}/seeds"
  [[ -d "${bmark_dir}/runtime" ]] && cp -r "${bmark_dir}/runtime" "${send_dir}"
  ls "${bmark_dir}"/*.dict &> /dev/null && \
    cp "${bmark_dir}"/*.dict "${send_dir}"
  ls "${building_dir}"/*.dict &> /dev/null && \
    cp "${building_dir}"/*.dict "${send_dir}"

  [[ "${FUZZING_ENGINE}" == "afl" ]] && cp "${AFL_SRC}/afl-fuzz" "${send_dir}"
  [[ "${FUZZING_ENGINE}" == "honggfuzz" ]] && cp "${HONGGFUZZ_SRC}/honggfuzz" "${send_dir}"
}

# Starts a runner VM
create_or_start_runner() {
  local instance_name=$1
  local metadata="benchmark=$2,fengine=$3,trial=$4,experiment=${EXPERIMENT}"
  metadata="${metadata},bucket=${GSUTIL_BUCKET}"
  local startup_script="/tmp/${instance_name}-start-docker.sh"
  {
    echo "#!/bin/bash"
    echo "while ! docker run --rm -e INSTANCE_NAME=${instance_name} \\"
    echo "  --cap-add SYS_PTRACE --name=runner-container \\"
    echo "  gcr.io/fuzzer-test-suite/runner /work/startup-runner.sh"
    echo "do"
    echo "  echo 'Error pulling image, retrying...'"
    echo "done 2>&1 | tee /tmp/runner-log.txt"
  } > "${startup_script}"
  create_or_start "${instance_name}" "${SERVICE_ACCOUNT}" \
    "${CLOUDSDK_COMPUTE_ZONE}" "${metadata}" "startup-script=${startup_script}"
}

# Handles the initialization of all runner VMs for a given benchmark.
handle_benchmark() {
  local benchmark=$1
  local fengine_config=$2
  local fengine_name="$(basename "${fengine_config}")"
  local building_dir="${WORK}/build/${benchmark}-${fengine_name}"

  build_benchmark "${benchmark}" "${fengine_config}" "${building_dir}"

  while read fuzzer_name; do
    local fuzzer_suffix="${fuzzer_name#${benchmark}-${FUZZING_ENGINE}}"
    local bmark_fuzzer="${benchmark}${fuzzer_suffix}"
    local send_dir="${WORK}/send/${bmark_fuzzer}-${fengine_name}"
    package_benchmark_fuzzer "${benchmark}" "${fuzzer_name}" \
      "${fengine_config}" "${building_dir}" "${send_dir}"
    rsync_delete "${send_dir}" \
      "${EXP_BUCKET}/binary-folders/${bmark_fuzzer}-${fengine_name}"

    # GCloud instance names must match the following regular expression:
    # '[a-z](?:[-a-z0-9]{0,61}[a-z0-9])?'
    local instance_name="$( \
      echo "r-${EXPERIMENT}${bmark_fuzzer}${fengine_name}" \
      | tr '[:upper:]' '[:lower:]' \
      | tr -d '.')"
    for (( i=0; i < RUNNERS; i++ )); do
      create_or_start_runner "${instance_name}${i}" "${bmark_fuzzer}" \
        "${fengine_name}" "${i}" &
    done
  done < <(find "${building_dir}" -mindepth 1 -maxdepth 1 \
    -name "${benchmark}-${FUZZING_ENGINE}*" -printf "%f\n")

  rm -rf "${building_dir}"
}

# Make a "plain" coverage build for a benchmark
make_measurer() {
  local benchmark=$1
  local building_dir="${WORK}/coverage-builds/${benchmark}"

  mkdir -p "${building_dir}"
  (cd "${building_dir}" && exec_in_clean_env \
    "FUZZING_ENGINE=coverage ${WORK}/FTS/${benchmark}/build.sh")

  while read fuzzer_name; do
    local fuzzer_suffix="${fuzzer_name#${benchmark}-coverage}"
    mv "${building_dir}/${fuzzer_name}" \
      "${WORK}/coverage-binaries/${benchmark}${fuzzer_suffix}-coverage"
  done < <(find "${building_dir}" -mindepth 1 -maxdepth 1 \
    -name "${benchmark}-coverage*" -printf "%f\n")

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
  UBSAN_OPTIONS=coverage=1 timeout 5m "${coverage_binary}" \
    $(comm -13 <(ls "${corpus1}") <(ls "${corpus2}") \
      | while read line; do echo "${corpus2}/${line}"; done)
}

# Process a corpus, generate a human readable report, send the report to gsutil
# Processing includes: decompress, use sancov.py, etc
measure_coverage() {
  local fengine_config=$1
  local benchmark=$2
  local trial=$3
  local fengine_name="$(basename "${fengine_config}")"
  local bmark_fengine_trial_dir="${benchmark}/${fengine_name}/trial-${trial}"
  local bmark_trial="${benchmark}-${fengine_name}/trial-${trial}"
  local measurement_dir="${WORK}/measurement-folders/${bmark_fengine_trial_dir}"
  local corpus_dir="${measurement_dir}/corpus"
  local prev_corpus_dir="${measurement_dir}/last-corpus"
  local sancov_dir="${measurement_dir}/sancovs"
  local report_dir="${measurement_dir}/reports"
  local experiment_dir="${WORK}/experiment-folders/${bmark_trial}"

  rm -rf "${corpus_dir}" "${sancov_dir}"
  mkdir -p "${corpus_dir}" "${sancov_dir}" "${report_dir}" "${prev_corpus_dir}"

  local covered_pcs_file="${report_dir}/covered-pcs.txt"
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
  local this_time=$((this_cycle * 20))
  while grep "^${this_cycle}$" "${experiment_dir}/results/skipped-cycles" \
    &> /dev/null; do
    # Record empty stats for proper data aggregation later.
    echo "${this_time}," >> "${report_dir}/coverage-graph.csv"
    echo "${this_time}," >> "${report_dir}/corpus-size-graph.csv"
    echo "${this_time}," >> "${report_dir}/corpus-elems-graph.csv"
    this_cycle=$((this_cycle + 1))
    this_time=$((this_cycle * 20))
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
      coverage="$(echo "${coverage}" | sed 's/[^0-9]*//g')"
      local corpus_size="${corpus_size_line##*,}"
      corpus_size="$(echo "${corpus_size}" | sed 's/[^0-9]*//g')"
      local corpus_elems="${corpus_elems_line##*,}"
      corpus_elems="$(echo "${corpus_elems}" | sed 's/[^0-9]*//g')"
    else
      # No corpus archive because we've processed all our archives already.
      return 1
    fi
  else
    # We have a new corpus archive.  Collect stats on it.
    # Extract corpus
    echo "Corpus #${this_cycle} found for:"
    echo "  benchmark: ${benchmark}"
    echo "  fengine: ${fengine_name}"
    echo "  trial: ${trial}"

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
    local corpus_size="$(find "${corpus_dir}" -maxdepth 1 -type f -print0 \
      | xargs -0 stat -c %s \
      | awk '{sum+=$1} END {print sum}')"
    local corpus_elems="$(find "${corpus_dir}" -maxdepth 1 -type f | wc -l)"

    # Save corpus for comparison next cycle
    rm -rf "${prev_corpus_dir}"
    mv "${corpus_dir}" "${prev_corpus_dir}"

    # Move this corpus archive to the processed folder so that rsync doesn't
    # need to check it anymore.
    local src_archive="${EXP_BUCKET}/experiment-folders/${bmark_trial}"
    src_archive="${src_archive}/corpus/corpus-archive-${this_cycle}.tar.gz"
    local dst_archive="${EXP_BUCKET}/processed-folders/${bmark_trial}"
    dst_archive="${dst_archive}/corpus-archive-${this_cycle}.tar.gz"
    p_gsutil mv "${src_archive}" "${dst_archive}"
  fi

  # If we got our first crash this cycle, mark this cycle in the CSV.
  if grep "^${this_cycle}$" "${experiment_dir}/results/first-crash-cycle" \
    &> /dev/null; then
    coverage="${coverage}X"
    corpus_size="${corpus_size}X"
    corpus_elems="${corpus_elems}X"
  fi

  # Finish generating human readable report
  echo "${this_time},${coverage}" >> "${report_dir}/coverage-graph.csv"
  echo "${this_time},${corpus_size}" >> "${report_dir}/corpus-size-graph.csv"
  echo "${this_time},${corpus_elems}" >> "${report_dir}/corpus-elems-graph.csv"

  echo "LATEST_CYCLE=${this_cycle}" > "${report_dir}/latest-cycle"
  rsync_delete "${report_dir}" \
    "${EXP_BUCKET}/reports/${bmark_fengine_trial_dir}"
  return 0
}

# Processes all synced corpora for a given fuzzer.
process_corpora() {
  while measure_coverage "$1" "$2" "$3"; do :; done
}

main() {
  declare -xr EXP_BUCKET="${GSUTIL_BUCKET}/${EXPERIMENT}"
  declare -xr WEB_BUCKET="${GSUTIL_WEB_BUCKET}/${EXPERIMENT}"

  mkdir "${WORK}/build" "${WORK}/send" "${WORK}/build-logs"

  # Stripped down equivalent of "gcloud init"
  gcloud auth activate-service-account "${SERVICE_ACCOUNT}" \
    --key-file="${WORK}/FTS/engine-comparison/config/autogen-PRIVATE-key.json"
  gcloud config set project "${PROJECT}"

  # This config file defines $BMARKS
  . "${WORK}/FTS/engine-comparison/config/bmarks.cfg"
  # Now define $BENCHMARKS. Encode aliases here
  case "${BMARKS}" in
    all)
      while read benchmark; do
        BENCHMARKS="${BENCHMARKS} $(basename "$(dirname "${benchmark}")")"
      done < <(find "${SCRIPT_DIR}/.." -name "build.sh")
      ;;
    most)
      while read benchmark; do
        local bmark_name="$(basename "$(dirname "${benchmark}")")"
        if [[ "${bmark_name}" != "c-ares-CVE-2016-5180" ]]; then
          BENCHMARKS="${BENCHMARKS} ${bmark_name}"
        fi
      done < <(find "${SCRIPT_DIR}/.." -name "build.sh")
      ;;
    small) BENCHMARKS="c-ares-CVE-2016-5180 re2-2014-12-09" ;;
    none) BENCHMARKS="" ;;
    three) BENCHMARKS="libssh-2017-1272 json-2017-02-12 proj4-2017-08-14" ;;
    *) BENCHMARKS="$(echo "${BMARKS}" | tr ',' ' ')" ;;
  esac
  readonly BENCHMARKS

  # Reset google cloud results before doing experiments
  p_gsutil rm -r "${EXP_BUCKET}/experiment-folders" "${EXP_BUCKET}/reports"

  # Record Clang revision before build.
  CLANG_REVISION="$(clang --version \
    | grep "clang version" \
    | grep -o "svn[0-9]*" \
    | grep -o "[0-9]*")"
  # If clang --version doesn't have revision, try extracting it from image tag.
  [[ -z "${CLANG_REVISION}" ]] && CLANG_REVISION="$(gcloud container images \
    list-tags gcr.io/fuzzer-test-suite/dispatcher \
    | grep latest \
    | grep -o 'clang-r[0-9]*' \
    | grep -o '[0-9]*')"
  export CLANG_REVISION

  # Outermost loops
  while read fengine_config; do
    download_engine "${fengine_config}"
    for benchmark in ${BENCHMARKS}; do
      local fengine_name="$(basename "${fengine_config}")"
      handle_benchmark "${benchmark}" "${fengine_config}" 2>&1 \
        | tee "${WORK}/build-logs/${benchmark}-${fengine_name}.txt" &
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
    make_measurer "${benchmark}" 2>&1 \
      | tee "${WORK}/build-logs/${benchmark}-cov.txt" &
  done
  wait

  rsync_delete "${WORK}/build-logs" "${EXP_BUCKET}/build-logs"

  mkdir -p "${WORK}/experiment-folders"
  mkdir -p "${WORK}/prev-experiment-folders"
  mkdir -p "${WORK}/measurement-folders"

  p_gsutil rm -r "${EXP_BUCKET}/processed-folders"

  # Compile list of all benchmark folder names.
  BENCHMARK_FOLDERS=""
  while read fuzzer_name; do
    BENCHMARK_FOLDERS="${BENCHMARK_FOLDERS} ${fuzzer_name%-coverage}"
  done < <(find "${WORK}/coverage-binaries" -mindepth 1 -maxdepth 1 \
    -name "*-coverage" -printf "%f\n")
  readonly BENCHMARK_FOLDERS

  # Start detached process to update graphs
  live_graphing_loop "${BENCHMARK_FOLDERS}" & disown

  # wait_period defines how frequently the dispatcher generates new reports for
  # every benchmark with every fengine. For a large number of runner VMs,
  # wait_period in dispatcher.sh can be smaller than it is in runner.sh
  local wait_period=10
  local next_sync=${SECONDS}
  local sync_num=1
  local keep_going=true
  while [[ "${keep_going}" = true ]]; do
    local sleep_time=$((next_sync - SECONDS))
    if [[ ${sleep_time} -gt 0 ]]; then
      sleep ${sleep_time}
    else
      next_sync=${SECONDS}
    fi

    # Prevent calling measure_coverage before runner VM begins
    if p_gsutil ls "${EXP_BUCKET}" | grep "experiment-folders" > /dev/null; then
      echo "Doing sync #${sync_num}..."
      rsync_delete "${EXP_BUCKET}/experiment-folders" \
        "${WORK}/experiment-folders"
      for benchmark in ${BENCHMARK_FOLDERS}; do
        while read fengine_config; do
          for (( i=0; i < RUNNERS; i++ )); do
            process_corpora "${fengine_config}" "${benchmark}" "${i}" &
          done
        done < <(find "${WORK}/fengine-configs" -type f)
      done
      if [[ $((sync_num % 10)) -eq 0 ]]; then
        # Only check diffs every 10 syncs to avoid unnecessarily slowing
        # down this loop.
        if diff -qr "${WORK}/experiment-folders" \
          "${WORK}/prev-experiment-folders" > /dev/null; then
          keep_going=false
        fi
        rm -rf "${WORK}/prev-experiment-folders"
        cp -r "${WORK}/experiment-folders" "${WORK}/prev-experiment-folders"
      fi
      wait
      sync_num=$((sync_num + 1))
    fi

    next_sync=$((next_sync + wait_period))
  done

  # We're done. Stop this dispatcher to save resources.
  gcloud compute instances delete --zone="${CLOUDSDK_COMPUTE_ZONE}" -q \
    "${INSTANCE_NAME}"
}

main "$@"
