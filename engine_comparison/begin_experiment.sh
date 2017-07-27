#/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh
. ${SCRIPT_DIR}/common-harness.sh

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}"
# DISPATCHER_IMAGE_FAMILY=${DISPATCHER_IMAGE_FAMILY:-"ubuntu-1604-lts"} # Maybe container optimized
# export PROJECT_NAME="google.com:fuzz-comparisons"

# These will frequently/usually be defined by the user
export JOBS=${JOBS:-8}
export N_ITERATIONS=${N_ITERATIONS:-5}

# Define $BENCHMARKS
if [[ $1 == 'all' ]]; then
  for b in $(find ${SCRIPT_DIR}/../*/build.sh -type f); do
    BENCHMARKS="$BENCHMARKS $(basename $(dirname $b))"
  done
#elif [[ $1 == 'other alias' ]]; do
else
  BENCHMARKS=$(echo $1 | tr ',' ' ')
fi

echo "Restarting gcloud instance. Instance should already be created (with gcloud_creator.sh)"
# Start one gcloud instance for the dispatcher
gcloud compute instances start $INSTANCE_NAME --zone=$GCLOUD_ZONE

# Can't ssh immediately
while :
do
  sleep 6 # arbitrary
  ! (gcloud compute ssh $INSTANCE_NAME --command="mkdir ~/input" --zone=$GCLOUD_ZONE \
    | grep "ERROR") && break # Break loop as soon as there is no error
done

# Send configs for the fuzzing engine
FENGINE_CONFIGS=${@:2}

if [[ -d tmp-configs ]]; then
  rm -r tmp-configs
fi
mkdir tmp-configs
for FENGINE in $FENGINE_CONFIGS; do
  cp $FENGINE tmp-configs/$FENGINE
done
gcloud compute scp tmp-configs/ ${INSTANCE_NAME}:~/input --recurse --zone=$GCLOUD_ZONE
rm -r tmp-configs

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gcloud compute scp $(dirname $SCRIPT_DIR) ${INSTANCE_NAME}:~/input --recurse --zone=$GCLOUD_ZONE
gcloud compute ssh $INSTANCE_NAME --command="mv ~/input/$(basename $(dirname ${SCRIPT_DIR})) ~/input/FTS" --zone="$GCLOUD_ZONE"

# Run dispatcher with Docker
DISPATCHER_COMMAND="sudo docker build -f ~/input/FTS/engine_comparison/ --build-arg run-script=dispatcher.sh ~/input"
gcloud compute ssh $INSTANCE_NAME --command="$DISPATCHER_COMMAND" --zone=$GCLOUD_ZONE


# TODO appropriately rsync some type of loop e.g.
# for time in 1m 5m 10m 30m 1h; do
#  sleep $time
#  gsutil rsync ${GSE_BUCKET_NAME}:${DIRECTORY}
# done
#
# TODO end script properly
# gcloud compute instances stop $INSTANCE_NAME
