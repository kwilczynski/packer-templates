#!/bin/bash

#
# grub.sh
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

KERNEL_OPTIONS=(
    quiet divider=10 console=tty1
    tsc=reliable elevator=noop
    net.ifnames=0 biosdevname=0
    vsyscall=emulate mce=0
)

readonly KERNEL_OPTIONS=$(echo "${KERNEL_OPTIONS[@]}")

sed -i -e \
    's/.*GRUB_HIDDEN_TIMEOUT=.*/GRUB_HIDDEN_TIMEOUT=0/' \
    /etc/default/grub

sed -i -e \
    's/.*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' \
    /etc/default/grub

sed -i -e \
    's/.*GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY=true/' \
    /etc/default/grub

sed -i -e \
    "s/.*GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${KERNEL_OPTIONS}\"/" \
    /etc/default/grub

# Remove any repeated (de-duplicate) Kernel options.
OPTIONS=$(sed -e \
    "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${KERNEL_OPTIONS}\"/" \
    /etc/default/grub | \
        grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' | \
            sed -e 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/\1/' | \
                tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

sed -i -e \
    "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"${OPTIONS}\"/" \
    /etc/default/grub

# Add include directory should it not exist.
[[ -d /etc/default/grub.d ]] || mkdir -p /etc/default/grub.d

# Disable the GRUB_RECORDFAIL_TIMEOUT.
cat <<'EOF' > /etc/default/grub.d/99-disable-recordfail.cfg
GRUB_RECORDFAIL_TIMEOUT=0
EOF

# Remove not needed legacy grub configuration file.
rm -f /boot/grub/menu.lst*

# Not really needed.
rm -f /boot/grub/device.map

update-initramfs -u -k all
update-grub

grub-install --no-floppy /dev/sda
