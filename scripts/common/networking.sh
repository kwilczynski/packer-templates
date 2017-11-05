#!/bin/bash

#
# networking.sh
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
set -o pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Get details about the Ubuntu release ...
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

if ufw status &>/dev/null; then
    ufw disable

    # Make sure to disable the ufw service.
    {
        if [[ $UBUNTU_VERSION == '16.04' ]]; then
            systemctl stop ufw
            systemctl disable ufw
        else
            service ufw stop
            update-rc.d -f ufw disable
        fi
    } || true
fi

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Make sure to install the package, as often Amazon image used as the
# source would not have it installed resulting in a failure to bring
# the network interface (eth0) up on boot.
if ! dpkg -s ethtool &>/dev/null; then
    # Refresh packages index only when needed.
    UPDATE_STAMP='/var/lib/apt/periodic/update-success-stamp'
    if [[ ! -f $UPDATE_STAMP ]] || \
       (( $(date +%s) - $(date -r $UPDATE_STAMP +%s) > 900 )); then
        apt-get --assume-yes update
    fi

    apt-get --assume-yes install ethtool
fi

if [[ -d /etc/network/interfaces.d ]]; then
    cat <<'EOF' > /etc/network/interfaces.d/eth0.cfg
auto eth0
iface eth0 inet dhcp
pre-up sleep 2
post-up ethtool -K eth0 tso off gso off lro off
EOF

  chown root: /etc/network/interfaces.d/*
  chmod 644 /etc/network/interfaces.d/*

  cat <<'EOF' > /etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
EOF
else
    cat <<'EOF' >> /etc/network/interfaces
pre-up sleep 2
post-up ethtool -K eth0 tso off gso off lro off
EOF
fi

chown root: /etc/network/interfaces
chmod 644 /etc/network/interfaces
