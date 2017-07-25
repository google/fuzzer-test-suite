#/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}"
DISPATCHER_IMAGE_FAMILY=${DISPATCHER_IMAGE_FAMILY:-"ubuntu-1604-lts"} # Maybe container optimized
export PROJECT_NAME="google.com:fuzz-comparisons"

# These will frequently/usually be defined by the user
export JOBS=${JOBS:-8}
export N_ITERATIONS=${N_ITERATIONS:-5}

# Define $BENCHMARKS
if [[ $1 == 'all' ]]; then
  for b in $(find ${SCRIPT_DIR}/*/build.sh -type f); do
    BENCHMARKS="$BENCHMARKS $(basename $(dirname $b))"
  done
#elif [[ $1 == 'other alias' ]]; do
else
  BENCHMARKS=$(echo $1 | tr ',' ' ')
fi

# Create one gcloud instance for the dispatcher
gcloud compute instances create $INSTANCE_NAME --image-family=$DISPATCHER_IMAGE_FAMILY --image-project=ubuntu-os-cloud

# Send configs for the fuzzing engine
export FENGINE_CONFIGS_DIR=${FENGINE_CONFIGS_DIR:-"~/fuzzing_engine_configs"}
FENGINE_CONFIGS=${@:2}

rm -rf ${SCRIPT_DIR}/tmp-configs
mkdir ${SCRIPT_DIR}/tmp-configs
for FENGINE in $FENGINE_CONFIGS; do
  cp $FENGINE tmp-configs/
done
gcloud compute scp --recurse ${SCRIPT_DIR}/tmp-configs ${INSTANCE_NAME}:${FENGINE_CONFIGS_DIR}/
rm -rf ${SCRIPT_DIR}/tmp-configs

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gcloud compute scp --recurse $SCRIPT_DIR $INSTANCE_NAME:~/

# Run dispatcher with Docker
DISPATCHER_COMMAND="docker build -f ~/${SCRIPT_DIR}/engine_comparison/ ."
gcloud compute ssh $INSTANCE_NAME --command=$DISPATCHER_COMMAND



# TODO appropriately rsync some type of loop e.g.
# for time in 1m 5m 10m 30m 1h; do
#  sleep $time
#  gsutil rsync ${GSE_BUCKET_NAME}:${DIRECTORY}
# done
#
#
# gcloud compute instances stop/delete $INSTANCE_NAME
