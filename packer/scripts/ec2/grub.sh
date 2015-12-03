#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

KERNEL_OPTIONS=(
    quiet divider=10 tsc=reliable
    elevator=noop net.ifnames=0
    biosdevname=0 console=ttyS0
    xen_emul_unplug=unnecessary
)

readonly KERNEL_OPTIONS=$(echo "${KERNEL_OPTIONS[@]}")

sed -i -e \
    "s/^default\(\s\).*/default\10/" \
    /boot/grub/menu.lst

sed -i -e \
    "s/^timeout\(\s\).*/timeout\10/" \
    /boot/grub/menu.lst

sed -i -e \
    "s/#.alternative=.*/# alternative=false/" \
    /boot/grub/menu.lst

sed -i -e \
    "s/#.groot=.*/# groot=(hd0,0)/" \
    /boot/grub/menu.lst

sed -i -e \
    "s/#.memtest86=.*/# memtest86=false/" \
    /boot/grub/menu.lst

sed -i -e \
    "s/#.indomU=.*/# indomU=detect/" \
    /boot/grub/menu.lst

# Remove any repeated (de-duplicate) Kernel options.
OPTIONS=$(sed -e \
    "s/#.defoptions=\(.*\)/# defoptions=\1 ${KERNEL_OPTIONS}/" \
    /boot/grub/menu.lst | \
        egrep '#.defoptions=' /boot/grub/menu.lst | \
            sed -e 's/.*defoptions=//' | \
            tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

sed -i -e \
    "s/#.defoptions=.*/# defoptions=${OPTIONS}/" \
    /boot/grub/menu.lst

sed -i -e \
    's/console=hvc0/console=ttyS0/g' \
    /boot/grub/menu.lst

# We don't care about UEFI firmware in case of legacy grub.
sed -i -e \
    's/.*LABEL=UEFI.*//' \
    /etc/fstab

sed -i -e '/^$/d' \
    /etc/fstab

unset UCF_FORCE_CONFFOLD
unset UCF_FORCE_CONFFNEW

export UCF_FORCE_CONFFNEW=1

ucf --purge /var/run/grub/menu.lst

update-initramfs -u -k all
update-grub -y

if [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
    # Select correct root device. We should still
    # be able to boot as we use "LABEL=" to make
    # the kernel scan for the appropriate device.
    ROOT_DEVICE='/dev/xvda'
    if [[ ! -b $ROOT_DEVICE ]]; then
        ROOT_DEVICE='/dev/sda'
    fi

    # Make sure not to use grub from the volume snapshot.
    grub-install --no-floppy $ROOT_DEVICE
fi

# Not really needed.
rm -f /boot/grub/device.map
