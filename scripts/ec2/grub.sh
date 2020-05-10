#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

KERNEL_OPTIONS=(
    'quiet'
    'divider=10'
    'tsc=reliable'
    'elevator=noop'
    'net.ifnames=0'
    'biosdevname=0'
    'console=tty1'
    'console=ttyS0'
    'xen_emul_unplug=unnecessary'
    'vsyscall=emulate'
    'mce=0'
)

# Support both grub and grub2 style configuration.
if detect_grub2; then
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

    # Remove not needed settings override.
    rm -f /etc/default/grub.d/50-cloudimg-settings.cfg

    # Add include directory should it not exist.
    [[ -d /etc/default/grub.d ]] || mkdir -p /etc/default/grub.d

    # Disable the GRUB_RECORDFAIL_TIMEOUT.
    cat <<'EOF' > /etc/default/grub.d/99-disable-recordfail.cfg
GRUB_RECORDFAIL_TIMEOUT=0
EOF

    # Remove not needed legacy grub configuration file.
    rm -f /boot/grub/menu.lst*
else
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

    sed -i -e \
        's/console=hvc0/console=ttyS0/g' \
        /boot/grub/menu.lst

    # Remove any repeated (de-duplicate) Kernel options.
    OPTIONS=$(sed -e \
        "s/^#\sdefoptions=\(.*\)/# defoptions=\1 ${KERNEL_OPTIONS[*]}/" \
        /boot/grub/menu.lst | \
            grep -E '^#\sdefoptions=' | \
                sed -e 's/.*defoptions=//' | \
                    tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    sed -i -e \
        "s/^#\sdefoptions=.*/# defoptions=${OPTIONS}/" \
        /boot/grub/menu.lst

    unset UCF_FORCE_CONFFOLD
    unset UCF_FORCE_CONFFNEW

    export UCF_FORCE_CONFFNEW=1

    ucf --purge /var/run/grub/menu.lst
fi

# We don't care about UEFI firmware in case of legacy grub.
sed -i -e \
    's/.*LABEL=UEFI.*//' \
    /etc/fstab

sed -i -e '/^$/d' \
    /etc/fstab

# Not really needed.
rm -f /boot/grub/device.map

update-initramfs -u -k all

UPDATE_GRUB_OPTION=''
if update-grub --help | grep -qF -- '-y'; then
    UPDATE_GRUB_OPTION+='-y'
fi

update-grub "$UPDATE_GRUB_OPTION"

if [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
    # Select correct root device. We should still
    # be able to boot as we use "LABEL=" to make
    # the kernel scan for the appropriate device.
    ROOT_DEVICE='/dev/xvda'
    if [[ ! -b "$ROOT_DEVICE" ]]; then
        ROOT_DEVICE='/dev/sda'
    fi

    # Make sure not to use grub from the volume snapshot.
    grub-install --no-floppy "$ROOT_DEVICE"
fi
