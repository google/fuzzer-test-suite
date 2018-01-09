# Google Cloud Platform (GCP) Configuration

Instructions to configure a GCP project for running A/B fuzzing experiments.

## Project Configuration
Create a new project and enable billing as described
[here](https://cloud.google.com/resource-manager/docs/creating-managing-projects).

## Quota Configuration
Decide which region you want to run your experiments in and [request quota
increases](https://console.cloud.google.com/iam-admin/quotas) for that region
according to your expected experiment sizes.  Consider the number of benchmarks
`B` you will run, the number of fuzzing configurations `F` you will compare, the
number of trials `T` you will run per fuzzer, and the number of simultaneous
experiments `E` you will execute.  Given those parameters, the minimum quota
requirements are:

- `500*E` GB regional persistent disk SSD.
- `10*B*F*T*E` GB regional persistent disk standard.
- `2*B*F*T*E + 16*E` regional CPUs.

## Network Configuration
[Create a new VPC network](https://console.cloud.google.com/networking/networks)
called `runner-net` with automatic subnets and regional routing mode.  After the
network is created, click on it and then edit the subnet for your region to
enable Google Private access.  This will allow instances on this subnet to use
Google services without having an externally-visible IP address.

Also add a firewall rule to the default network, allowing TCP traffic on port 22
from 10.0.0.0/8.  This will allow SSH connections to dispatcher instances from
other GCP instances.

## Bucket Configuration
[Create two Cloud Storage
buckets](https://cloud.google.com/storage/docs/creating-buckets). One will be
used for storing experiment data, and the other will be used for displaying web
reports.

Now make your web report bucket publicly accessible:
```
gsutil acl ch -u AllUsers:R gs://YOUR_WEB_BUCKET
gsutil defacl ch -u AllUsers:R gs://YOUR_WEB_BUCKET
```
This will allow you to view web reports by simply navigating to their URLs in
your browser.

## Service Account Configuration
Create a [new service
account](https://cloud.google.com/compute/docs/access/create-enable-service-accounts-for-instances)
with Project Editor role.
