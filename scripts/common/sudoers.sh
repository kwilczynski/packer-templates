#!/bin/bash

#
# sudoers.sh
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

sed -i -e \
    's/^\(.*env_keep = \"\)/\1PATH /' \
    /etc/sudoers

sed -i -e \
    's/^Defaults.*requiretty/Defaults\t!requiretty/' \
    /etc/sudoers

sed -i -e \
    "/Defaults\s\+env_reset/a Defaults\texempt_group=sudo" \
    /etc/sudoers

sed -i -e \
    "s/%sudo\s*ALL=(ALL:ALL) ALL/%sudo\tALL=NOPASSWD:ALL/g" \
    /etc/sudoers

if ! grep -q 'env_keep' /etc/sudoers; then
    sed -i -e \
        '/Defaults\s\+env_reset/a Defaults\tenv_keep = "PATH HOME SSH_AGENT_PID SSH_AUTH_SOCK"' \
        /etc/sudoers
fi

if ! grep -q 'requiretty' /etc/sudoers; then
    sed -i -e \
        '/Defaults\s\+env_reset/i Defaults\t!requiretty,!tty_tickets' \
        /etc/sudoers
fi

chown root: /etc/sudoers
chmod 440 /etc/sudoers

for user in root ubuntu; do
    if getent passwd $user &>/dev/null; then
        echo "${user}:$(date | md5sum)" | chpasswd
        passwd -l $user
    fi
done

cat <<'EOF' > /etc/securetty
console
tty1
vc/1
EOF

chown root: /etc/securetty
chmod 440 /etc/securetty

# Make sure to disallow access to "su" for everyone
# other than a root user or a decidated group.
dpkg-statoverride --update --add root sudo 4750 /bin/su
