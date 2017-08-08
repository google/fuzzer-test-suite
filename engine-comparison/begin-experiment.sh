#/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh
. ${SCRIPT_DIR}/common-harness.sh

[[ -z $2 ]] && echo "Usage: Must specify benchmarks,\
 as well as at least one fuzzing engine config" && exit 1

# Send configs for the fuzzing engine
FENGINE_CONFIGS=${@:2}

if [[ -d fengine-configs ]]; then
  rm -r fengine-configs
fi
mkdir fengine-configs
for FENGINE in $FENGINE_CONFIGS; do
  cp $FENGINE fengine-configs/$FENGINE
done

CONFIG=${SCRIPT_DIR}/config
[[ -e ${CONFIG}/bmarks.cfg ]] && rm ${CONFIG}/bmarks.cfg
echo "BMARKS=$1" > ${CONFIG}/bmarks.cfg

# Pass service account auth key
if [[ ! -e ${CONFIG}/autogen-PRIVATE-key.json ]]; then
  gcloud iam service-accounts keys create ${CONFIG}/autogen-PRIVATE-key.json \
    --iam-account=$SERVICE_ACCOUNT --key-file-type=json
fi


# -m parallelizes operation; -r sets recursion, -d syncs deletion of files
gsutil -m rsync -rd fengine-configs ${GSUTIL_BUCKET}/dispatcher-input/fengine-configs
rm -r fengine-configs

# Send the entire local FTS repository to the dispatcher;
# Local changes to any file will propagate
gsutil -m rsync -rd $(dirname $SCRIPT_DIR) ${GSUTIL_BUCKET}/dispatcher-input/FTS

#gsutil -m acl ch -r -u ${SERVICE_ACCOUNT}:O ${GSUTIL_BUCKET}

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}"

create_or_start $INSTANCE_NAME # $SCRIPT_DIR/dispatcher-startup.sh
robust_begin_gcloud_ssh $INSTANCE_NAME

gcloud compute ssh $INSTANCE_NAME \
  --command="mkdir -p ~/input && gsutil -m rsync -rd ${GSUTIL_BUCKET}/dispatcher-input ~/input \
 && bash ~/input/FTS/engine-comparison/dispatcher-startup.sh"
 # && chown --reference=/home ~/input

# TODO appropriately rsync some type of loop e.g.
# for time in 1m 5m 10m 30m 1h; do
#  sleep $time
#  gsutil rsync ${GSE_BUCKET_NAME}:${DIRECTORY}
# done
#
# TODO end script properly
# gcloud compute instances stop $INSTANCE_NAME
# gcloud service-account delete key
