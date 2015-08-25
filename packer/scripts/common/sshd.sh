#!/bin/bash

set -e

rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

sed -i -e 's/.*UseDNS yes/UseDNS no/' \
    /etc/ssh/sshd_config

sed -i -e 's/.*PermitRootLogin yes/PermitRootLogin no/' \
    /etc/ssh/sshd_config

sed -i -e 's/.*GSSAPIAuthentication yes/GSSAPIAuthentication no/' \
    /etc/ssh/sshd_config
