#!/bin/bash

#
# clean-up.sh
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

readonly COMMON_FILES='/var/tmp/common'

# Get details about the Ubuntu release ...
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --wait 1 --tries 2 --spider http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

if [[ $UBUNTU_VERSION == '16.04' ]]; then
    systemctl daemon-reload
fi

for service in syslog syslog-ng rsyslog; do
    {
        if [[ $UBUNTU_VERSION == '16.04' ]]; then
            systemctl stop $service
        else
            service $service stop
        fi
    } || true
done

logrotate -f /etc/logrotate.conf || true

# Remove everything (configuration files, etc.) left after
# packages were uninstalled (often unused files are left on
# the file system).
dpkg -l | grep '^rc' | awk '{ print $2 }' | \
    xargs apt-get --assume-yes purge

# Remove not really needed Kernel source packages.
dpkg -l | awk '{ print $2 }' | grep -E 'linux-(source|headers)-[0-9]+' | \
    grep -v "$(uname -r | sed -e 's/\-generic//;s/\-lowlatency//')" | \
    xargs apt-get --assume-yes purge

# Remove old Kernel images that are not the current one.
dpkg -l | awk '{ print $2 }' | grep -E 'linux-image-.*-generic' | \
    grep -v $(uname -r) | xargs apt-get --assume-yes purge

# Remove old Kernel images that are not the current one.
dpkg -l | awk '{ print $2 }' | grep -E -- '.*-dev:?.*' | grep -vE '(libc|gcc)' | \
    xargs apt-get --assume-yes purge

# A list of packages to be purged.
PACKAGES_TO_PURGE=( $(cat ${COMMON_FILES}/packages-purge.list 2>/dev/null) )

# Keep these packages when building an Instance Store type image (needed by
# the Amazon EC2 AMI Tools), and remove otherwise.
if [[ $AMAZON_EC2 == 'no' ]] || [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
    # Remove Ruby ONLY when any sensible version was not installed, or
    # when the Itamae Ruby gem (and its dependencies) were not installed.
    if [[ -z $RUBY_VERSION ]] || [[ -z $ITAMAE_VERSION ]] && \
          ! ( apt-cache policy | grep -qF 'brightbox' )
    then
        PACKAGES_TO_PURGE+=(
          ^libruby[0-9]\.
          ^ruby[0-9]\.
          ^ruby-switch$
          ^rubygems-integration$
        )
    fi
    PACKAGES_TO_PURGE+=( kpartx parted unzip )
fi

if [[ $AMAZON_EC2 == 'yes' ]]; then
  # Remove packages that are definitely not needed in EC2 ...
  PACKAGES_TO_PURGE+=( ^wireless-* crda iw linux-firmware mdadm open-iscsi )
fi

if [[ $UBUNTU_VERSION == '16.04' ]]; then
  # Remove LXD and LXCFS as Docker will be installed.
  PACKAGES_TO_PURGE+=( lxd lxcfs )
fi

for package in "${PACKAGES_TO_PURGE[@]}"; do
    apt-get --assume-yes purge $package || true
done

for option in '--purge autoremove' 'autoclean' 'clean all'; do
    apt-get --assume-yes $option
done

# Keep the "tty1" virtual terminal to allow access in a case
# of the network connection being down and/or inaccessible.
for file in /etc/init/tty{2,3,4,5,6}.conf; do
    dpkg-divert --rename $file
done

sed -i -e \
    's#^\(ACTIVE_CONSOLES="/dev/tty\).*#\11"#' \
    /etc/default/console-setup

# Disable the Ubuntu splash screen (during boot time).
for file in /etc/init/plymouth*.conf; do
    dpkg-divert --rename $file
done

# Disable synchronization of the system clock
# with the hardware clock (CMOS).
for file in /etc/init/hwclock*.conf; do
    dpkg-divert --rename $file
done

# No need to automatically adjust the CPU scheduler.
{
    if [[ $UBUNTU_VERSION == '16.04' ]]; then
        systemctl stop ondemand
        systemctl disable ondemand
    else
        service ondemand stop
        update-rc.d -f ondemand disable
    fi
} || true

# Disabled for now, as it breaks the "initscripts" package post-install job.
# dpkg-divert --rename /etc/init.d/ondemand

rm -f /etc/blkid.tab \
      /dev/.blkid.tab

rm -f /core*

rm -f /boot/grub/menu.lst_* \
      /boot/grub/menu.lst~ \
      /boot/*.old*

rm -f /etc/network/interfaces.old

rm -f /etc/apt/apt.conf.d/99dpkg \
      /etc/apt/apt.conf.d/00CDMountPoint

rm -f VBoxGuestAdditions_*.iso \
      VBoxGuestAdditions_*.iso.?

rm -f /root/.bash_history \
      /root/.rnd* \
      /root/.hushlogin \
      /root/*.tar \
      /root/.*_history \
      /root/.lesshst \
      /root/.gemrc

rm -rf /root/.cache \
       /root/.{gem,gems} \
       /root/.vim* \
       /root/.ssh \
       /root/*

for user in vagrant ubuntu; do
    if getent passwd $user &>/dev/null; then
        rm -f /home/${user}/.bash_history \
              /home/${user}/.rnd* \
              /home/${user}/.hushlogin \
              /home/${user}/*.tar \
              /home/${user}/.*_history \
              /home/${user}/.lesshst \
              /home/${user}/.gemrc

        rm -rf /home/${user}/.cache \
               /home/${user}/.{gem,gems} \
               /home/${user}/.vim* \
               /home/${user}/*
    fi
done

rm -rf /etc/lvm/cache/.cache

# Clean if there are any Python software installed there.
if ls /opt/*/share &>/dev/null; then
    find /opt/*/share -type d -name 'man' -o -name 'doc' -exec rm -rf '{}' \;
fi

if [[ $AMAZON_EC2 == 'no' ]]; then
    # VMWare uses DHCP behind the scene, thus we need to remove
    # the host name entry as it's not going to be valid any more
    # after the machine will be brought up again in the future.
    if [[ $PACKER_BUILDER_TYPE =~ ^vmware.*$ ]]; then
        IP_ADDRESS=$(hostname -I | cut -d' ' -f 1)
        sed -i -e \
            "/^${IP_ADDRESS}/d; /^$/d" \
            /etc/hosts
    fi

    rm -rf /tmp/* /var/tmp/* /usr/tmp/*
else
    if [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
        # Will be excluded during the volume bundling process
        # only when building Instance Store type image, thus
        # we clean-up manually.
        rm -rf /tmp/* /var/tmp/* /usr/tmp/*
    fi
fi

rm -rf /usr/share/{doc,man}/* \
       /usr/local/share/{doc,man}

sed -i -e \
    '/^.\+fd0/d;/^.\*floppy0/d' \
    /etc/fstab

# Remove entry for "/mnt" from /etc/fstab,
# we do not want any extra volume (if
# available) to be mounted automatically.
sed -i -e \
    '/^.\+\/mnt/d;/^.\*\/mnt/d' \
    /etc/fstab

sed -i -e \
    '/^#/!s/\s\+/\t/g' \
    /etc/fstab

rm -rf /var/lib/ubuntu-release-upgrader \
       /var/lib/update-notifier \
       /var/lib/update-manager \
       /var/lib/man-db \
       /var/lib/apt-xapian-index \
       /var/lib/ntp/ntp.drift \
       /var/lib/{lxd,lxcfs}

rm -rf /lib/recovery-mode

rm -rf /var/lib/cloud/data/scripts \
       /var/lib/cloud/scripts/per-instance \
       /var/lib/cloud/data/user-data*

# Prevent storing of the MAC address as part of the network
# interface details saved by systemd/udev, and disable support
# for the Predictable (or "consistent") Network Interface Names.
UDEV_RULES=(
    70-persistent-net.rules
    75-persistent-net-generator.rules
    80-net-setup-link.rules
    80-net-name-slot.rules
)

for rule in "${UDEV_RULES[@]}"; do
    rm -f /etc/udev/rules.d/${rule}
    ln -sf /dev/null /etc/udev/rules.d/${rule}
done

if [[ $UBUNTU_VERSION == '16.04' ]]; then
    # Override systemd configuration ...
    rm -f /etc/systemd/network/99-default.link
    ln -sf /dev/null /etc/systemd/network/99-default.link
fi

rm -rf /dev/.udev \
       /var/lib/{dhcp,dhcp3}/* \
       /var/lib/dhclient/*

if [[ $AMAZON_EC2 == 'yes' ]]; then
    # Get rid of this file, alas clout-init will probably
    # create it again automatically so that it can wreck
    # network configuration. These files, sadly cannot be
    # simply a symbolic links to /dev/null, as cloud-init
    # would change permission of the device node to 0644,
    # which is disastrous, every time during the system
    # startup.
    rm -f \
      /etc/network/interfaces.d/50-cloud-init.cfg \
      /etc/systemd/network/50-cloud-init-eth0.link \
      /etc/udev/rules.d/70-persistent-net.rules

    pushd /etc/network/interfaces.d &>/dev/null
    mknod .null c 1 3
    ln -sf .null 50-cloud-init.cfg
    popd &>/dev/null

    pushd /etc/udev/rules.d &>/dev/null
    mknod .null c 1 3
    ln -sf .null 70-persistent-net.rules
    popd &>/dev/null
fi

# Remove surplus locale (and only retain the English one).
mkdir -p /tmp/locale

for directory in /usr/share/locale /usr/share/locale-langpack; do
    for locale in en en@boldquot en_US; do
        LOCALE_PATH=${directory}/${locale}
        if [[ -d $LOCALE_PATH ]]; then
            mv $LOCALE_PATH /tmp/locale/
        fi
    done

    rm -rf ${directory}/*

    if [[ -d $directory ]]; then
        mv /tmp/locale/* ${directory}/
    fi
done

rm -rf /tmp/locale

find /etc /var /usr -type f -name '*~' -exec rm -f '{}' \;
find /var/log /var/cache /var/lib/apt -type f -exec rm -rf '{}' \;

if [[ $AMAZON_EC2 == 'yes' ]]; then
    find /etc /root /home -type f -name 'authorized_keys' -exec rm -f '{}' \;
else
  # Only the Vagrant user should keep its SSH key. Everything
  # else will either use the user left form the image creation
  # time, or a new key will be fetched and stored by means of
  # cloud-init, etc.
  if ! getent passwd vagrant &> /dev/null; then
      find /etc /root /home -type f -name 'authorized_keys' -exec rm -f '{}' \;
  fi
fi

mkdir -p /var/lib/apt/periodic \
         /var/lib/apt/{lists,archives}/partial

chown -R root: /var/lib/apt
chmod -R 755 /var/lib/apt

# Newer version of Ubuntu introduce a dedicated
# "_apt" user, which owns the temporary files.
if [[ $UBUNTU_VERSION == '16.04' ]]; then
    chown _apt: /var/lib/apt/lists/partial
fi
apt-cache gencaches

touch /var/log/{lastlog,wtmp,btmp}

chown root: /var/log/{lastlog,wtmp,btmp}
chmod 644 /var/log/{lastlog,wtmp,btmp}
