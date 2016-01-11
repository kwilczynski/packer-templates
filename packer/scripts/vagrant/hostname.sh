#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')
readonly HOSTNAME="ubuntu$(echo $UBUNTU_VERSION | tr -d '.')"
readonly IP_ADDRESS=$(hostname -I | cut -d' ' -f 1)

cat <<EOF | tee /etc/hosts
127.0.0.1 localhost.localdomain localhost loopback
${IP_ADDRESS} ${HOSTNAME}.localdomain ${HOSTNAME} ubuntu
EOF

chown root: /etc/hosts
chmod 644 /etc/hosts

echo $HOSTNAME | tee \
    /proc/sys/kernel/hostname \
    /etc/hostname

chown root: /etc/hostname
chmod 644 /etc/hostname

echo 'localdomain' | tee \
    /proc/sys/kernel/domainname

hostname -F /etc/hostname
service rsyslog restart
