#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export EC2_AMITOOL_HOME=/var/tmp/ec2-ami-tools
export EC2_HOME=$EC2_AMITOOL_HOME
export PATH=${PATH}:${EC2_AMITOOL_HOME}/bin

hash -r

ec2-bundle-vol -P mbr -e '/var/tmp/*,/tmp/*' --no-filter --batch "$@"
