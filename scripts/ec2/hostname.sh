#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

cat <<EOF > /etc/hosts
127.0.0.1 localhost.localdomain localhost loopback
EOF

chown root: /etc/hosts
chmod 644 /etc/hosts

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    HOSTNAME=$(wget -O- http://169.254.169.254/latest/meta-data/local-hostname 2>/dev/null)
    if [[ -n $HOSTNAME ]]; then
        hostnamectl --static set-hostname "$HOSTNAME"
    fi

    hostnamectl --static set-deployment 'amazon'
    hostnamectl --static set-icon-name 'network-server'
    hostnamectl --static set-location "$PACKER_BUILDER_TYPE"
    hostnamectl --static set-chassis 'server'
fi

for service in syslog syslog-ng rsyslog systemd-journald; do
    {
        if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
            systemctl stop "$service"
        else
            service "$service" stop
        fi
    } || true
done
