#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

cat <<'EOF' > /etc/sudoers.d/ubuntu
Defaults:ubuntu !requiretty,!tty_tickets
Defaults:ubuntu env_keep += "SSH_AGENT_PID SSH_AUTH_SOCK"

ubuntu ALL=(ALL) NOPASSWD: ALL
EOF

chown -R root: /etc/sudoers.d
chmod 440 /etc/sudoers.d/ubuntu
