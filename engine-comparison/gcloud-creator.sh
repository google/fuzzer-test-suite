#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");

. $(dirname $0)/../common.sh
. ${SCRIPT_DIR}/common-harness.sh

DD=$(date +%d)
MM=$(date +%m)
INSTANCE_NAME="dispatcher-${DD}-${MM}" # may want flexibility i.e. ${2:-"dispatcher-${DD}-${MM}"}

COMMAND=$1
[[ $COMMAND != "create" ]] && [[ $COMMAND != "delete" ]] && echo "USAGE: First argument must be 'create' or 'delete' " && exit 1

gcloud_${COMMAND} $INSTANCE_NAME
