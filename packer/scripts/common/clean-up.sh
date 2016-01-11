#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly COMMON_FILES='/var/tmp/common'

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --tries 2 --wait 1 -O - http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

for service in syslog syslog-ng rsyslog; do
    service $service stop || true
done

logrotate -f /etc/logrotate.conf || true

# Remove everything (configuration files, etc.) left after
# packages were uninstalled (often unused files are left on
# the file system).
dpkg -l | grep '^rc' | awk '{ print $2 }' | \
    xargs apt-get -y --force-yes purge

# Remove not really needed Kernel source packages.
dpkg -l | awk '{ print $2 }' | grep -E 'linux-(source|headers)-[0-9]+' | \
    grep -v "$(uname -r | sed -e 's/\-generic//;s/\-lowlatency//')" | \
    xargs apt-get -y --force-yes purge

# Remove old Kernel images that are not the current one.
dpkg -l | awk '{ print $2 }' | grep -E 'linux-image-.*-generic' | \
    grep -v $(uname -r) | xargs apt-get -y --force-yes purge

# Remove old Kernel images that are not the current one.
dpkg -l | awk '{ print $2 }' | grep -E -- '.*-dev:?.*' | grep -vE '(libc|gcc)' | \
    xargs apt-get -y --force-yes purge

PACKAGES_TO_PURGE=( $(cat ${COMMON_FILES}/packages-purge-list 2>/dev/null) )

# Keep these packages when building an Instance Store type image (needed by
# the Amazon EC2 AMI Tools), and remove otherwise.
if [[ $AMAZON_EC2 == 'no' ]] || [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
    PACKAGES_TO_PURGE+=( ^libruby* ^ruby* kpartx parted unzip )
fi

for package in "${PACKAGES_TO_PURGE[@]}"; do
    apt-get -y --force-yes purge $package || true
done

for option in '--purge autoremove' 'autoclean' 'clean all'; do
    apt-get -y --force-yes $option
done

# Keep the "tty1" virtual terminal to allow access in a case
# of the network connection being down and/or inaccessible.
for file in /etc/init/tty{2,3,4,5,6}.conf; do
    dpkg-divert --rename $file
done

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
service ondemand stop
update-rc.d -f ondemand disable

# Disabled for now, as it breaks the "initscripts" package post-install job.
# dpkg-divert --rename /etc/init.d/ondemand

rm -f /core*

rm -f /boot/grub/menu.lst_* \
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

sed -i -e \
    '/^#/!s/\s\+/\t/g' \
    /etc/fstab

rm -rf /var/lib/ubuntu-release-upgrader \
       /var/lib/update-notifier \
       /var/lib/update-manager \
       /var/lib/man-db \
       /var/lib/apt-xapian-index \
       /var/lib/ntp/ntp.drift

rm -rf /lib/recovery-mode

rm -rf /var/lib/cloud/data/scripts \
       /var/lib/cloud/scripts/per-instance \
       /var/lib/cloud/data/user-data*

# Prevent storing of the MAC address as part of the
# network interface details saved by udev.
rm -f /etc/udev/rules.d/{z25,70}-persistent-net.rules \
      /lib/udev/rules.d/75-persistent-net-generator.rules

mkdir /etc/udev/rules.d/{z25,70}-persistent-net.rules

chown root: /etc/udev/rules.d/{z25,70}-persistent-net.rules
chmod 755 /etc/udev/rules.d/{z25,70}-persistent-net.rules

rm -rf /dev/.udev \
       /var/lib/{dhcp,dhcp3}/* \
       /var/lib/dhclient/*

# Remove surplus locale (and only retain the English one).
mkdir -p /tmp/locale

for locale in en en_US; do
    LOCALE_PATH=/usr/share/locale/${locale}
    if [[ -d $LOCALE_PATH ]]; then
        mv $LOCALE_PATH /tmp/locale/
    fi
done

rm -rf /usr/share/locale/*
mv /tmp/locale/* /usr/share/locale/

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

apt-cache gencaches

touch /var/log/{lastlog,wtmp,btmp}

chown root: /var/log/{lastlog,wtmp,btmp}
chmod 644 /var/log/{lastlog,wtmp,btmp}
