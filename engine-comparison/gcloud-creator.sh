#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Creates or deletes a dispatcher VM for the current day.

. "$(dirname "$0")/../common.sh"
. "${SCRIPT_DIR}/common-harness.sh"

readonly INSTANCE_NAME="dispatcher-$(date +%d)-$(date +%m)"
case $1 in
  create) gcloud_create "${INSTANCE_NAME}" ;;
  delete) gcloud_delete "${INSTANCE_NAME}" ;;
  *) echo "USAGE: $0 [create|delete]" && exit 1 ;;
esac
