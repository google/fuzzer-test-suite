#!/bin/bash -eu
# Stops the experiment specified in the experiment configuration passed as an
# argument to this script.

readonly EXPERIMENT_CONFIG="$1"
. "${EXPERIMENT_CONFIG}"

gcloud compute instances delete -q $(gcloud compute instances list \
  | cut -d " " -f 1 \
  | grep "^r-${EXPERIMENT}") &

gcloud compute instances delete -q "dispatcher-${EXPERIMENT}"
