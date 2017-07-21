# Engine Comparison

This is a set of scripts to run A/B testing among different fuzzing engines.

## gcloud

The `gcloud` CLI is a part of the [Google Cloud SDK](https://cloud.google.com/sdk/gcloud/), which can be installed [here](https://cloud.google.com/sdk/downloads). 

Currently, these scripts only run on Google Cloud, but support for alternatives will be incorporated.

## Usage

From one's local computer, call ` ${FTS}/engine_comparison/begin_experiment.sh`

Script behavior can be modified through a variety of environment variables, but 
the most necessary specification is the location of the directory which
specifices the configuration of each fuzzing engine. The location of this
directory should be in `$FENGINE_CONFIG_DIR`
