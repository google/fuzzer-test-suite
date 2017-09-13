#!/bin/bash

# Not calling common scripts, because they don't allow being called in directory
#. $(dirname $0)/../../common.sh
#. ${SCRIPT_DIR}/../common-harness.sh
# This is all that we need from them:
GSUTIL_BUCKET="gs://fuzzer-test-suite"

#[[ -d reports ]] && mv reports old-reports

# rsync wipes all previous results from generate-report.go, as well as and all .html files
gsutil -m rsync -rd ${GSUTIL_BUCKET}/reports .
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

