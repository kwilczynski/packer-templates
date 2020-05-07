#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

KERNEL_OPTIONS=(
    'quiet'
    'divider=10'
    'console=tty1'
    'console=ttyS0,9600n8'
    'tsc=reliable'
    'elevator=noop'
    'net.ifnames=0'
    'biosdevname=0'
    'vsyscall=emulate'
    'mce=0'
)

sed -i -e \
    's/.*GRUB_TERMINAL=.*/GRUB_TERMINAL="serial console"/' \
    /etc/default/grub

sed -i -e \
    's/.*GRUB_SERIAL_COMMAND=.*/GRUB_SERIAL_COMMAND="serial --speed=9600 --unit=0 --word=8 --parity=no --stop=1"/' \
    /etc/default/grub

sed -i -e \
    's/.*GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE="menu"/' \
    /etc/default/grub

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
    "s/.*GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${KERNEL_OPTIONS[*]}\"/" \
    /etc/default/grub

# Remove any repeated (de-duplicate) Kernel options.
OPTIONS=$(sed -e \
    "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${KERNEL_OPTIONS[*]}\"/" \
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
