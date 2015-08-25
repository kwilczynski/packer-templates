#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

KERNEL_OPTIONS=(
    quiet divider=10
    tsc=reliable
    elevator=noop
    net.ifnames=0
    biosdevname=0
)

readonly KERNEL_OPTIONS=$(echo "${KERNEL_OPTIONS[@]}")

sed -i -e \
    's/GRUB_HIDDEN_TIMEOUT=.*/GRUB_HIDDEN_TIMEOUT=0/g' \
    /etc/default/grub

sed -i -e \
    's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/g' \
    /etc/default/grub

sed -i -e \
    's/.*GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY=true/g' \
    /etc/default/grub

sed -i -e \
    "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${KERNEL_OPTIONS}\"/g" \
    /etc/default/grub

rm -f /boot/grub/device.map

update-initramfs -u -k all
update-grub

grub-install --no-floppy /dev/sda
