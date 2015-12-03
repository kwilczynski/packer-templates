#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

ROOT_PARTITION='/dev/xvda1'
if [[ ! -b $ROOT_PARTITION ]]; then
    ROOT_PARTITION='/dev/sda1'
fi

# This should not be needed, but just in case
# we attempt to re-size the root partition.
resize2fs -p $ROOT_PARTITION
