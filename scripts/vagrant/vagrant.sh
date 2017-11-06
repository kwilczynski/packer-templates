#!/bin/bash

#
# vagrant.sh
#
# Copyright 2016-2017 Krzysztof Wilczynski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly VAGRANT_FILES='/var/tmp/vagrant'

[[ -d $VAGRANT_FILES ]] || mkdir -p $VAGRANT_FILES

cat <<'EOF' > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty,!tty_tickets
Defaults:vagrant env_keep += "SSH_AGENT_PID SSH_AUTH_SOCK"

vagrant ALL=(ALL) NOPASSWD: ALL
EOF

chown -R root: /etc/sudoers.d
chmod 440 /etc/sudoers.d/vagrant

mkdir -p /home/vagrant/.ssh

if [[ ! -f ${VAGRANT_FILES}/vagrant.pub ]]; then
    wget --no-check-certificate -O ${VAGRANT_FILES}/vagrant.pub \
        https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
fi

cp -f ${VAGRANT_FILES}/vagrant.pub \
      /home/vagrant/.ssh/authorized_keys

chown -R vagrant: /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
chmod 600 /home/vagrant/.ssh/*

rm -f ${VAGRANT_FILES}/vagrant.pub
