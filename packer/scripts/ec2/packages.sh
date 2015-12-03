#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# Dependencies needed by the Amazon EC2 AMI Tools.
apt-get -y --force-yes --no-install-recommends install \
    grub \
    parted \
    kpartx \
    unzip \
    ruby1.9.3

apt-mark manual grub
apt-mark manual parted

hash -r
