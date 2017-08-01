#/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh
. ${SCRIPT_DIR}/common-harness.sh

[[ -z $2 ]] && echo "Warning: Usage: Please specify benchmarks, as well as at least one fuzzing engine"

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}"
# DISPATCHER_IMAGE_FAMILY=${DISPATCHER_IMAGE_FAMILY:-"ubuntu-1604-lts"} # Maybe container optimized
# export PROJECT_NAME="google.com:fuzz-comparisons"

# Start one gcloud instance for the dispatcher
# echo "Restarting gcloud instance. Instance should already be created (with gcloud_creator.sh)"
create_or_start $INSTANCE_NAME
robust_begin_gcloud_ssh $INSTANCE_NAME
gcloud compute ssh $INSTANCE_NAME --command="mkdir ~/input" --zone=$GCLOUD_ZONE

# Send configs for the fuzzing engine
FENGINE_CONFIGS=${@:2}

if [[ -d fengine-configs ]]; then
  rm -r fengine-configs
fi
mkdir fengine-configs
for FENGINE in $FENGINE_CONFIGS; do
  cp $FENGINE fengine-configs/$FENGINE
done

gcloud compute scp fengine-configs/ ${INSTANCE_NAME}:~/input --recurse --zone=$GCLOUD_ZONE
rm -r fengine-configs

# These will frequently/usually be defined by the user
JOBS=${JOBS:-8}
N_ITERATIONS=${N_ITERATIONS:-5}

# Send configs
AUTOGEN=${SCRIPT_DIR}/autogen

if [[ ! -d $AUTOGEN ]]; then
  mkdir $AUTOGEN
fi

if [[ ! -e ${AUTOGEN}/dispatcher.config ]]; then
  echo "BMARKS=$1" > ${AUTOGEN}/dispatcher.config
fi

if [[ ! -e ${AUTOGEN}/worker.config ]]; then
  echo "N_ITERATIONS=$N_ITERATIONS" > ${AUTOGEN}/worker.config
  echo "JOBS=$JOBS" >> ${AUTOGEN}/worker.config
fi
# Pass service account auth key
if [[ ! -e ${AUTOGEN}/dispatcher-key.json ]]; then
  gcloud iam service-accounts keys create ${AUTOGEN}/dispatcher-key.json \
    --iam-account=$SERVICE_ACCOUNT --key-file-type=json
fi

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gcloud compute scp $(dirname $SCRIPT_DIR) ${INSTANCE_NAME}:~/input --recurse --zone=$GCLOUD_ZONE

# Could use "! [[ -d ~/input/FTS ]] &&" to prevent deletion
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
# gcloud service-account delete key
