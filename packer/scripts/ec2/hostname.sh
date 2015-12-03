#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

cat <<EOF | tee /etc/hosts
127.0.0.1 localhost.localdomain localhost loopback
EOF

chown root:root /etc/hosts
chmod 644 /etc/hosts
