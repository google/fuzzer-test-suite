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

echo "Restarting gcloud instance. Instance should already be created (with gcloud_creator.sh)"
# Start one gcloud instance for the dispatcher
gcloud compute instances start $INSTANCE_NAME --zone=$GCLOUD_ZONE

# Can't ssh immediately
while :
do
  sleep 6 # arbitrary
  ! (gcloud compute ssh $INSTANCE_NAME --command="mkdir ~/input" --zone=$GCLOUD_ZONE \
    2>&1 | grep "ERROR") && break # Break loop as soon as there is no error
  echo "GCloud VM isn't ready yet. Rerunning SSH momentarily"
done
# TODO write function gcloud_robust_ssh

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

# These will frequently/usually be defined by the user
JOBS=${JOBS:-8}
N_ITERATIONS=${N_ITERATIONS:-5}
# Send configs
echo 'BMARKS=$1' > ${SCRIPT_DIR}/dispatcher.config
echo $'N_ITERATIONS=$N_ITERATIONS\nJOBS=$JOBS' > ${SCRIPT_DIR}/worker.config

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gcloud compute scp $(dirname $SCRIPT_DIR) ${INSTANCE_NAME}:~/input --recurse --zone=$GCLOUD_ZONE

# ! [[ -d ~/input/FTS ]] &&
gcloud compute ssh $INSTANCE_NAME --command="rm -rf ~/input/FTS && \
  mv ~/input/$(basename $(dirname ${SCRIPT_DIR})) ~/input/FTS " --zone=$GCLOUD_ZONE

# Run dispatcher with Docker
DISPATCHER_COMMAND="~/input/FTS/engine-comparison/run.sh /~/work/FTS/engine-comparison/dispatcher.sh"
gcloud compute ssh $INSTANCE_NAME --command="$DISPATCHER_COMMAND" --zone=$GCLOUD_ZONE


# TODO appropriately rsync some type of loop e.g.
# for time in 1m 5m 10m 30m 1h; do
#  sleep $time
#  gsutil rsync ${GSE_BUCKET_NAME}:${DIRECTORY}
# done
#
# TODO end script properly
# gcloud compute instances stop $INSTANCE_NAME
