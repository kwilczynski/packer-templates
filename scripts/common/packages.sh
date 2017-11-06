#!/bin/bash

#
# packages.sh
#
# Copyright 2016-2017 Krzysztof Wilczynski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Get details about the Ubuntu release ...
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --wait 1 --tries 2 --spider http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

# A list of common packages to be installed.
PACKAGES=(
    ntp haveged irqbalance vim heirloom-mailx
    apt-transport-https software-properties-common
    python-software-properties wget curl iptables
)

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install $package
done

{
    if [[ $UBUNTU_VERSION == '16.04' ]]; then
        systemctl stop ntp
    else
        service ntp stop
    fi
} || true

sed -i -e \
    "s/.*NTPD_OPTS='\(.*\)'/NTPD_OPTS='\1 -4'/g" \
    /etc/default/ntp

# Makes time sync more aggressively in a VM. See
# http://kb.vmware.com/kb/1006427 for more details.
sed -i -e \
    '/.*restrict -6.*$/d;/.*restrict ::1$/d;1a\\ntinker panic 0' \
    /etc/ntp.conf

# Disable the monitoring facility to prevent attacks using ntpdc monlist
# command when default restrict does not include the noquery flag. See
# https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2013-5211 for more
# details.
sed -i -e \
    '/tinker panic.*/a disable monitor' \
    /etc/ntp.conf

if [[ $AMAZON_EC2 == 'yes' ]]; then
    sed -i -e '/server.*\.ubuntu\.pool\.ntp\.org/ s/\.ubuntu\.\(.*\)\s\?/\.amazon\.\1\ iburst/g' \
        /etc/ntp.conf
else
    sed -i -e \
        '/server.*\.ubuntu\.pool\.ntp\.org/ s/ubuntu\.\(.*\)/\1 iburst/' \
        /etc/ntp.conf
fi

update-alternatives --set editor /usr/bin/vim.basic
