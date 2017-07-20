#/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}"
DISPATCHER_IMAGE_FAMILY=${DISPATCHER_IMAGE_FAMILY:-"ubuntu-1604-lts"} # Container optimized?
export PROJECT_NAME=google.com:fuzz-comparisons

# These will frequently/usually be defined by the user
export JOBS=${JOBS:-8}
export N_ITERATIONS=${N_ITERATIONS:-5}
export ALL_BENCHMARKS=${ALL_BENCHMARKS:-"$(find "${SCRIPT_DIR}/" -type d)"} # Probably not the best default

# Create one gcloud instance for the dispatcher
gcloud compute instances create $INSTANCE_NAME --image_family=$DISPATCHER_IMAGE_FAMILY --image_project=$PROJECT_NAME

# Send specifications for each fuzzing engine
EXPORT FENGINE_CONFIGS_DIR=${FENGINE_CONFIGS_DIR:-"~/fuzzing_engine_configs"}
gcloud compute scp --recurse $FENGINE_CONFIGS_DIR $INSTANCE_NAME:~/

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gcloud compute scp --recurse $SCRIPT_DIR $INSTANCE_NAME:~/

# Run dispatcher with Docker
DISPATCHER_COMMAND="docker build ~/${SCRIPT_DIR}/engine_comparison/dispatcher/"
gcloud compute ssh $INSTANCE_NAME --command=$DISPATCHER_COMMAND



# TODO appropriately rsync some type of loop e.g.
# for time in 1m 5m 10m 30m 1h; do
#  sleep $time
#  gsutil rsync ${GSE_BUCKET_NAME}:${DIRECTORY}
# done
#
#
# gcloud compute instances stop/delete $INSTANCE_NAME
