#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get -y --force-yes --no-install-recommends install \
    ntp \
    haveged \
    irqbalance \
    vim \
    heirloom-mailx \
    apt-transport-https \
    software-properties-common \
    python-software-properties \
    wget \
    curl

apt-mark manual dkms
apt-mark manual apt-transport-https
apt-mark manual software-properties-common
apt-mark manual python-software-properties

service ntp stop
sed -i -e \
    "s/.*NTPD_OPTS='\(.*\)'/NTPD_OPTS='\1 -4'/g" \
    /etc/default/ntp

# Makes time sync more aggressively in a VM.
# see: http://kb.vmware.com/kb/1006427
sed -i -e \
    '/.*restrict -6.*$/d;/.*restrict ::1$/d;1a\\ntinker panic 0' \
    /etc/ntp.conf

sed -i -e \
    '/server.*\.ubuntu\.pool\.ntp\.org/ s/ubuntu\.//' \
    /etc/ntp.conf

update-alternatives --set editor /usr/bin/vim.basic
