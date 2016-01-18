#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

if ufw status &>/dev/null; then
    ufw disable
    service ufw stop
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
        apt-get -y --force-yes update
    fi

    apt-get -y --force-yes install ethtool
fi

if [[ -d /etc/network/interfaces.d ]]; then
    cat <<'EOF' | tee /etc/network/interfaces.d/eth0.cfg
auto eth0
iface eth0 inet dhcp
pre-up sleep 2
post-up ethtool -K eth0 tso off gso off lro off
EOF
else
    cat <<'EOF' | tee -a /etc/network/interfaces
pre-up sleep 2
post-up ethtool -K eth0 tso off gso off lro off
EOF
fi
