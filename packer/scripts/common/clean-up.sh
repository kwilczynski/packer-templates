#!/bin/bash

set -eu

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# Remove everything (configuration files, etc.) left after
# packages were uninstalled (often unused files are left on
# the file system).
dpkg -l | egrep '^rc' | awk '{ print $2 }' | \
    xargs apt-get -y --force-yes purge

dpkg -l | awk '{ print $2 }' | egrep 'linux-(source|headers)' | \
    grep -v "$(uname -r | sed -e 's/\-generic//;s/\-lowlatency//')" | \
    xargs apt-get -y --force-yes purge

# Remove old Kernel images that are not the current one.
dpkg -l | awk '{ print $2 }' | grep 'linux-image-.*-generic' | grep -v $(uname -r) | \
    xargs apt-get -y --force-yes purge

PACKAGES_TO_PURGE=(
    ^apport* ^avahi-* ^command-not-found* ^cryptsetup* ^debian-faq*
    ^doc-* ^grub-efi-amd64* ^libruby* ^libx11-* ^manpages* ^ppp* ^ruby*
    ^ubuntu-release-upgrader-core* ^update-manager-core* ^virtualbox*
    ^wireless-* ^zeitgeist* apt-xapian-index aptitude byobu cpp-doc
    crda cups debconf-i18n dictionaries dosfstools ed efibootmgr eject
    fdutils finger fonts-ubuntu-font-family-console foomatic-filters
    friendly-recovery g++ gcc-doc hplip iamerican ibritish info install-info
    installation-report iw kpartx krb5-locales laptop-detect libxcb1 libxext6
    libxmuu1 man-db mlocate modemmanager mutt ntfs-3g open-vm-tools parted
    open-vm-tools plymouth-theme-ubuntu-text policykit-1 pollinate
    popularity-contest powermgmt-base python-zeitgeist read-edid reportbug
    rhythmbox-plugin-zeitgeist run-one sbsigntool screen secureboot-db
    shim-signed smclient ubuntu-serverguide unity-lens-shopping wvdial
    update-notifier-common usbutils w3m wamerican whoopsie wpasupplicant
    xauth zeroinstall-injector mono-common libxcb1 fonts-dejavu-core
    fontconfig-config libfontconfig1 libxpm4 libgd3
)

for p in ${PACKAGES_TO_PURGE[@]}; do
    apt-get -y --force-yes purge $p 2> /dev/null || true
done

apt-get -y --force-yes --purge autoremove
apt-get -y --force-yes autoclean
apt-get -y --force-yes clean all

# Keep the "tty1" virtual terminal to allow access in a case
# of the network connection being down and/or inaccessible.
for f in /etc/init/tty{2,3,4,5,6}.conf; do
    dpkg-divert --rename $f
done

# Disable the Ubuntu splash screen (during boot time).
for f in /etc/init/plymouth*.conf; do
    dpkg-divert --rename $f
done

# Disable synchronization of the system clock
# with the hardware clock (CMOS).
for f in /etc/init/hwclock*.conf; do
    dpkg-divert --rename $f
done

# No need to automatically adjust the CPU scheduler.
service ondemand stop
update-rc.d -f ondemand disable

# VMWare uses DHCP behind the scene, thus we need to remove
# the host name entry as it's not going to be valid any more
# after the machine will be brought up again in the future.
if [[ $PACKER_BUILDER_TYPE =~ ^vmware.*$ ]]; then
    IP_ADDRESS=$(hostname -I | cut -d' ' -f 1)
    sed -i -e \
        "/^${IP_ADDRESS}/d; /^$/d" \
        /etc/hosts
fi

rm -f /boot/grub/menu.lst_*
rm -f /etc/network/interfaces.old
rm -f /etc/apt/apt.conf.d/99dpkg
rm -f VBoxGuestAdditions_*.iso VBoxGuestAdditions_*.iso.?

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

for u in vagrant ubuntu; do
    if getent passwd $u &>/dev/null; then
        rm -f /home/${u}/.bash_history \
              /home/${u}/.rnd* \
              /home/${u}/.hushlogin \
              /home/${u}/*.tar \
              /home/${u}/.*_history \
              /home/${u}/.lesshst \
              /home/${u}/.gemrc

        rm -rf /home/${u}/.cache \
               /home/${u}/.{gem,gems} \
               /home/${u}/.vim* \
               /home/${u}/*
    fi
done

rm -rf /usr/share/{doc,man}/*

rm -rf /tmp/* /var/tmp/*

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

chown root:root /etc/udev/rules.d/{z25,70}-persistent-net.rules
chmod 755 /etc/udev/rules.d/{z25,70}-persistent-net.rules

rm -rf /dev/.udev \
       /var/lib/{dhcp,dhcp3}/*

# Remove surplus locale (and only retain the English one).
mkdir -p /tmp/locale
mv /usr/share/locale/en* /tmp/locale/
rm -rf /usr/share/locale/*
mv /tmp/locale/en* /usr/share/locale/
rm -rf /tmp/locale

find /etc /var /usr -type f -name '*~' -exec rm -f '{}' \;
find /var/log /var/cache /var/lib/apt -type f -exec rm -rf '{}' \;

# Only the Vagrant user should keep its SSH key. Everything
# else will either use the user left form the image creation
# time, or a new key will be fetched and stored by means of
# cloud-init, etc.
if ! getent passwd vagrant &> /dev/null; then
    find /etc /root /home -type f -name 'authorized_keys' -exec rm -f '{}' \;
fi

mkdir -p /var/lib/apt/periodic \
         /var/lib/apt/{lists,archives}/partial

chown -R root:root /var/lib/apt
chmod -R 755 /var/lib/apt

apt-cache gencaches

touch /var/log/{lastlog,wtmp,btmp}

chown root:root /var/log/{lastlog,wtmp,btmp}
chmod 644 /var/log/{lastlog,wtmp,btmp}
