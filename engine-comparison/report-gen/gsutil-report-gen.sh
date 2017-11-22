#!/bin/bash
# Copyright 2016 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

# This script generates reports from the local machine. To produce reports,
# call this script from any directory. The folder "reports" will be cloned and manipulated,
# then the graphs will be hosted as a webpage on GCP Storage.

# Not calling common scripts, because they don't allow being called in
# directory:
#. $(dirname $0)/../../common.sh
#. ${SCRIPT_DIR}/../common-harness.sh
#. $(dirname $0)/../common-harness.sh

# This is all that we need from them:
readonly GSUTIL_BUCKET="gs://fuzzer-test-suite"
readonly GSUTIL_PUBLIC_BUCKET="gs://fuzzer-test-suite-public"

readonly EXP_BUCKET="${GSUTIL_BUCKET}/$1"
readonly WEB_BUCKET="${GSUTIL_PUBLIC_BUCKET}/$1"

[[ -d old-reports ]] && rm -rf old-reports
[[ -d reports ]] && mv reports old-reports
mkdir reports

# rsync -d wipes all previous results from generate-report.go, as well as all .html files
gsutil -m rsync -rd "${EXP_BUCKET}/reports" ./reports
go run generate-report.go

while read bm; do
  cp comparison-charts.html "${bm}/"
  find "${bm}" -maxdepth 1 -mindepth 1 -type d -exec \
    cp fengine-charts.html {}/ \;
done < <(find reports -maxdepth 1 -mindepth 1 -type d)

gsutil -m rsync -rd ./reports "${WEB_BUCKET}"
# Make all files public, each .html needs the .csvs as assets
gsutil -m acl -r ch -u AllUsers:R "${WEB_BUCKET}"
#rm -r ./reports
echo "View the most recent report at ${WEB_BUCKET}"
