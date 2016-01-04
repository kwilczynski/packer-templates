#!/bin/bash

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

for v in "${SSH_SETTINGS[@]}"; do
    SETTING=( $v )

    sed -i -e "s/^#\?${SETTING[0]}.*/${v}/" \
        /etc/ssh/sshd_config

    grep -qF "$v" /etc/ssh/sshd_config &> /dev/null || \
        echo "$v" | tee -a /etc/ssh/sshd_config
done
