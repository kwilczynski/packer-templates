#!/bin/bash

#
# motd.sh
#
# Copyright 2016 Krzysztof Wilczynski
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

# Get details about the Ubuntu release ...
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# Dependencies needed by Landscape.
PACKAGES=( python-twisted-core python-configobj landscape-common )

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install $package
done

# Remove the warranty information.
rm -f /etc/legal

rm -f /etc/update-motd.d/10-help-text \
      /etc/update-motd.d/51-cloudguest \
      /etc/update-motd.d/90-updates-available \
      /etc/update-motd.d/91-release-upgrade \
      /etc/update-motd.d/95-hwe-eol \
      /etc/update-motd.d/98-fsck-at-reboot \
      /etc/update-motd.d/98-reboot-required

mkdir -p /etc/landscape
chown root: /etc/landscape
chmod 755 /etc/landscape

cat <<'EOF' > /etc/landscape/client.conf
[sysinfo]
exclude_sysinfo_plugins = Temperature,LandscapeLink
EOF

chown root: /etc/landscape/client.conf
chmod 644 /etc/landscape/client.conf

if [[ -f /etc/init.d/landscape-client ]]; then
    {
        if [[ $UBUNTU_VERSION == '16.04' ]]; then
            systemctl stop landscape-client
            systemctl disable landscape-client
        else
          service landscape-client stop
          update-rc.d -f landscape-client disable
        fi
    } || true
fi

cat <<'EOF' > /etc/update-motd.d/99-footer
#!/bin/sh

# Add extra information when showing message of the day.

[ -f /etc/motd.tail ] && cat /etc/motd.tail 2>/dev/null || true

printf "\n"
exit 0
EOF

chown root: /etc/update-motd.d/99-footer
chmod 755 /etc/update-motd.d/99-footer

rm -f /etc/motd

rm -f /etc/motd.tail
touch /etc/motd.tail

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    if ! grep -q -E 'motd=.+motd(\.dynamic)?' /etc/pam.d/sshd; then
        sed -i -e \
            's#\(^session.*pam_motd.so\)\+#\1 motd=/run/motd noupdate\n&#' \
                /etc/pam.d/sshd
    else
        sed -i -e \
            's#\(motd=/run/motd\)\.dynamic\(.*\)#\1\2#' \
            /etc/pam.d/sshd
    fi

    if ! grep -q -E 'motd=.+motd(\.dynamic)?' /etc/pam.d/login; then
        sed -i -e \
            's#\(^session.*pam_motd.so\)\+#\1 motd=/run/motd noupdate\n&#' \
                /etc/pam.d/login
    else
        sed -i -e \
            's#\(motd=/run/motd\)\.dynamic\(.*\)#\1\2#' \
            /etc/pam.d/login
    fi

    run-parts --lsbsysinit /etc/update-motd.d > /run/motd

    chown root: /run/motd
    chmod 644 /run/motd
else
    run-parts --lsbsysinit /etc/update-motd.d > /var/run/motd.dynamic

    chown root: /var/run/motd.dynamic
    chmod 644 /var/run/motd.dynamic
fi
