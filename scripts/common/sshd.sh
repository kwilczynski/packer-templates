#!/bin/bash

#
# sshd.sh
#
# Copyright 2016 Krzysztof Wilczynski
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

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --tries 2 --wait 1 -O - http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

SSH_SETTINGS=(
    'UseDNS no'
    'PermitRootLogin no'
    'GSSAPIAuthentication no'
)

if [[ $AMAZON_EC2 == 'yes' ]]; then
    SSH_SETTINGS+=(
        'UseLogin no'
        'TCPKeepAlive no'
        'X11Forwarding no'
    )
fi

rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

for value in "${SSH_SETTINGS[@]}"; do
    SETTING=( $value )

    sed -i -e \
        "s/^#\?${SETTING[0]}.*/${value}/" \
        /etc/ssh/sshd_config

    grep -qF "$value" /etc/ssh/sshd_config || \
        echo "$value" >> /etc/ssh/sshd_config
done
