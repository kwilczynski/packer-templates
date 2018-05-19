#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

# Make sure to shut the network interface down, thus close the
# connections allowing for Packer to notice and reconnect.
cat <<'EOF' > /tmp/reboot.sh
sleep 10

pgrep -f sshd | xargs kill -9

INTERFACE=$(route -n | awk '/^0\./ { print $8 }')

if ifconfig &>/dev/null; then
    ifconfig $INTERFACE down
    ifconfig $INTERFACE up
else
    ip link set $INTERFACE down
    ip link set $INTERFACE up
fi

reboot -f
EOF

nohup bash /tmp/reboot.sh &>/dev/null &

sleep 60
