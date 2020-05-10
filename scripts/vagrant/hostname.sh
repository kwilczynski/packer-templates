#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

readonly PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE//-*}
readonly IP_ADDRESS=$(hostname -I | cut -d' ' -f 1)
readonly HOSTNAME="ubuntu$(detect_ubuntu_version | tr -d '.')"

cat <<EOF > /etc/hosts
127.0.0.1 localhost.localdomain localhost loopback
${IP_ADDRESS} ${HOSTNAME}.localdomain ${HOSTNAME} ubuntu
EOF

chown root: /etc/hosts
chmod 644 /etc/hosts

echo "$HOSTNAME" | tee \
    /proc/sys/kernel/hostname \
    /etc/hostname > /dev/null

chown root: /etc/hostname
chmod 644 /etc/hostname

echo 'localdomain' > /proc/sys/kernel/domainname

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    hostnamectl --static set-hostname "$HOSTNAME"
    hostnamectl --static set-deployment 'vagrant'
    hostnamectl --static set-icon-name 'network-server'
    hostnamectl --static set-location "$PACKER_BUILDER_TYPE"
    hostnamectl --static set-chassis 'server'
else
    hostname -F /etc/hostname
fi

for service in syslog syslog-ng rsyslog systemd-journald; do
    {
        if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
            systemctl restart "$service"
        else
            service "$service" restart
        fi
    } || true
done
