#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

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
    apt_get_update
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
