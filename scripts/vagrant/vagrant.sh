#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly VAGRANT_FILES='/var/tmp/vagrant'

[[ -d $VAGRANT_FILES ]] || mkdir -p "$VAGRANT_FILES"

cat <<'EOF' > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty,!tty_tickets
Defaults:vagrant env_keep += "SSH_AGENT_PID SSH_AUTH_SOCK"

vagrant ALL=(ALL) NOPASSWD: ALL
EOF

chown -R root: /etc/sudoers.d
chmod 440 /etc/sudoers.d/vagrant

mkdir -p /home/vagrant/.ssh

if [[ ! -f "${VAGRANT_FILES}/vagrant.pub" ]]; then
    wget -O "${VAGRANT_FILES}/vagrant.pub" \
        https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
fi

cp -f "${VAGRANT_FILES}/vagrant.pub" \
      /home/vagrant/.ssh/authorized_keys

chown -R vagrant: /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/*

rm -f "${VAGRANT_FILES}/vagrant.pub"
