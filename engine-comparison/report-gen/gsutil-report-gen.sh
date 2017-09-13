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
GSUTIL_BUCKET="gs://fuzzer-test-suite"

[[ -d reports ]] && mv reports old-reports
mkdir reports

# rsync -d wipes all previous results from generate-report.go, as well as all .html files
gsutil -m rsync -rd ${GSUTIL_BUCKET}/reports ./reports
go run generate-report.go

for bm in $(find reports -maxdepth 1 -mindepth 1 -type d); do
  for fe in $(find $bm -maxdepth 1 -mindepth 1 -type d); do
    cp setOfTrialCharts.html ${fe}/
  done
  cp setOfFengineCharts.html ${bm}/
done

gsutil -m rsync -rd ./reports ${GSUTIL_BUCKET}/webpage-graphs
# Make all files public, each .html needs the .csvs as assets
gsutil -m acl -r ch -u AllUsers:R ${GSUTIL_BUCKET}/webpage-graphs

#rm -r ./reports
echo "Navigate to ${GSUTIL_BUCKET}/webpage-graphs to view the most recent report"

