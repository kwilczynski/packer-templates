#!/bin/bash

set -e

SSH_SETTINGS=(
    'UseDNS no'
    'PermitRootLogin no'
    'GSSAPIAuthentication no'
)

rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

for v in "${SSH_SETTINGS[@]}"; do
    SETTING=( $v )

    sed -i -e "s/^#\?${SETTING[0]}.*/${v}/" \
        /etc/ssh/sshd_config

    egrep -q "$v" /etc/ssh/sshd_config &> /dev/null || \
        echo "$v" | tee -a /etc/ssh/sshd_config
done
