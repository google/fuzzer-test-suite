#!/bin/bash
# Copyright 2017 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
#
# Script to run on creation of the dispatcher VM.
# Configures dispatcher container and runs the dispatcher script.

gsutil -m rsync -r "${GSUTIL_BUCKET}/${EXPERIMENT}/input" "${WORK}"
find "${WORK}/FTS/" -name "*.sh" -exec chmod 750 "{}" \;
"${WORK}/FTS/engine-comparison/dispatcher.sh"
