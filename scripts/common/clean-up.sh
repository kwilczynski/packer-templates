#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly COMMON_FILES='/var/tmp/common'

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

readonly AMAZON_EC2=$(detect_amazon_ec2 && echo 'true')
readonly VMWARE=$(detect_vmware && echo 'true')
readonly PROXMOX=$(detect_proxmox && echo 'true')

[[ -d $COMMON_FILES ]] || mkdir -p "$COMMON_FILES"

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    systemctl daemon-reload
fi

for service in syslog syslog-ng rsyslog systemd-journald; do
    {
        if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
            systemctl stop "$service"
        else
            service "$service" stop
        fi
    } || true
done

logrotate -f /etc/logrotate.conf || true

# Remove the Ubuntu Extended Security Maintenance (ESM)
# as it is a paid feature only available to Canonical
# Advantage subscribers.
apt-key adv --batch --yes --delete-keys 'esm@canonical.com' 2>/dev/null || true
find /etc/apt/sources.list.d -type f -name 'ubuntu-esm-*' -print0 | \
    xargs -0 rm -f

# Remove everything (configuration files, etc.) left after
# packages were uninstalled (often unused files are left on
# the file system).
dpkg -l | grep '^rc' | awk '{ print $2 }' | \
    xargs apt-get --assume-yes purge

# Remove not really needed Kernel source packages.
dpkg -l | awk '{ print $2 }' | \
    grep -E '(linux-(source|headers)-[0-9]+|linux-aws-(source|headers)-[0-9]+)' | \
        grep -v "$(uname -r | sed -e 's/\-generic//;s/\-lowlatency//;s/\-aws//')" | \
            xargs apt-get --assume-yes purge

# Remove old Kernel images and modules that are not the current one.
dpkg -l | awk '{ print $2 }' | \
    grep -E 'linux-(image|modules)-.*-(generic|aws)' | \
        grep -v "$(uname -r)" | xargs apt-get --assume-yes purge

# Remove development packages.
dpkg -l | awk '{ print $2 }' | grep -E -- '.*-dev:?.*' | \
    grep -v -E "(libc|$(dpkg -s g++ &>/dev/null && echo 'libstdc++')|gcc)" | \
        xargs apt-get --assume-yes purge

# A list of packages to be purged.
PACKAGES_TO_PURGE=( $(cat "${COMMON_FILES}/packages-purge.list" 2>/dev/null) )

# Keep these packages when building an Instance Store type image (needed by
# the Amazon EC2 AMI Tools), and remove otherwise.
if [[ -z $AMAZON_EC2 || -z $PROXMOX || $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
    # Remove Ruby ONLY when any sensible version was not installed, or
    # when the Itamae Ruby gem (and its dependencies) were not installed.
    if [[ -z $RUBY_VERSION || -z $ITAMAE_VERSION ]] && \
          ! ( apt-cache policy | grep -q -F 'brightbox' )
    then
        PACKAGES_TO_PURGE+=(
            '^libruby[0-9]\.'
            '^ruby[0-9]\.'
            '^ruby-switch$'
            '^rubygems-integration$'
        )
    fi
    PACKAGES_TO_PURGE+=(
        'kpartx'
        'parted'
        'unzip'
    )
fi

if [[ -n $AMAZON_EC2 || -n $PROXMOX ]]; then
  # Remove packages that are definitely not needed in EC2 or Proxmox ...
    PACKAGES_TO_PURGE+=(
        '^wireless-*'
        'crda'
        'iw'
        'linux-firmware'
        'mdadm'
        'open-iscsi'
    )
fi

if [[ -n $AMAZON_EC2 ]]; then
  # Remove packages that are definitely not needed in EC2 ...
    PACKAGES_TO_PURGE+=(
        'lvm2'
    )
fi

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
  # Remove LXD and LXCFS as Docker will be installed.
    PACKAGES_TO_PURGE+=(
        'lxd'
        'lxcfs'
    )
fi

for package in "${PACKAGES_TO_PURGE[@]}"; do
    apt-get --assume-yes purge "$package" 2>/dev/null || true
done

for option in '--purge autoremove' 'autoclean' 'clean all'; do
    apt-get --assume-yes $option
done

# Regenerate Apt overrides for the kernel.
if [[ -f /etc/kernel/postinst.d/apt-auto-removal ]]; then
    bash /etc/kernel/postinst.d/apt-auto-removal
fi

# Keep the "tty1" virtual terminal to allow access in a case
# of the network connection being down and/or inaccessible.
for file in /etc/init/tty{2,3,4,5,6}.conf; do
    dpkg-divert --rename "$file"
done

sed -i -e \
    's#^\(ACTIVE_CONSOLES="/dev/tty\).*#\11"#' \
    /etc/default/console-setup

# Disable the Ubuntu splash screen (during boot time).
for file in /etc/init/plymouth*.conf; do
    dpkg-divert --rename "$file"
done

# Disable synchronization of the system clock
# with the hardware clock (CMOS).
for file in /etc/init/hwclock*.conf; do
    dpkg-divert --rename "$file"
done

# No need to automatically adjust the CPU scheduler.
{
    if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
        for option in stop disable; do
            systemctl "$option" ondemand || true
        done
    else
        service ondemand stop
        update-rc.d -f ondemand disable
    fi
} || true

dpkg-divert --rename /etc/init.d/ondemand

rm -f /usr/sbin/policy-rc.d

rm -f /.dockerenv \
      /.dockerinit

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
      /root/.wget* \
      /root/.gemrc \
      /roor/.sudo*

rm -Rf /root/.cache \
       /root/.{gem,gems} \
       /root/.vim* \
       /root/.ssh \
       /root/.gnupg \
       /root/*

 USERS=('vagrant')
 if [[ -z $PROXMOX ]]; then
     USERS+=('ubuntu')
 fi

for user in "${USERS[@]}"; do
    if getent passwd "$user" &>/dev/null; then
        rm -f /home/${user:?}/.bash_history \
              /home/${user:?}/.rnd* \
              /home/${user:?}/.hushlogin \
              /home/${user:?}/*.tar \
              /home/${user:?}/.*_history \
              /home/${user:?}/.lesshst \
              /home/${user:?}/.wget* \
              /home/${user:?}/.gemrc \
              /home/${user:?}/.sudo*

        rm -Rf /home/${user:?}/.cache \
               /home/${user:?}/.{gem,gems} \
               /home/${user:?}/.gnupg \
               /home/${user:?}/.vim* \
               /home/${user:?}/*
    fi
done

rm -Rf /etc/lvm/cache/.cache

# Clean if there are any Python software installed there.
if ls /opt/*/share &>/dev/null; then
    find /opt/*/share -type d \( -name 'man' -o -name 'doc' \) -print0 | \
        xargs -0 rm -Rf
fi

if [[ -z $AMAZON_EC2 ]]; then
    # VMWare uses DHCP behind the scene, thus we need to remove
    # the host name entry as it's not going to be valid any more
    # after the machine will be brought up again in the future.
    if [[ -n $VMWARE || -n $PROXMOX ]]; then
        IP_ADDRESS=$(hostname -I | cut -d' ' -f 1)
        sed -i -e \
            "/^${IP_ADDRESS}/d; /^$/d" \
            /etc/hosts
    fi

    rm -Rf /tmp/* /var/tmp/* /usr/tmp/*
else
    if [[ $PACKER_BUILDER_TYPE =~ ^amazon-ebs$ ]]; then
        # Will be excluded during the volume bundling process
        # only when building Instance Store type image, thus
        # we clean-up manually.
        rm -Rf /tmp/* /var/tmp/* /usr/tmp/*
    fi
fi

rm -Rf /usr/share/{doc,man}/* \
       /usr/local/share/{doc,man}

rm -Rf /usr/share/groff/* \
       /usr/share/info/* \
       /usr/share/lintian/* \
       /usr/share/linda/* \
       /usr/share/bug/*

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

rm -Rf /var/lib/ubuntu-release-upgrader \
       /var/lib/update-notifier \
       /var/lib/update-manager \
       /var/lib/man-db \
       /var/lib/apt-xapian-index \
       /var/lib/ntp/ntp.drift \
       /var/lib/{lxd,lxcfs}

rm -Rf /lib/recovery-mode

rm -Rf /var/lib/cloud/data/scripts \
       /var/lib/cloud/scripts/per-instance \
       /var/lib/cloud/data/user-data* \
       /var/lib/cloud/instance \
       /var/lib/cloud/instances/*

rm -Rf /var/log/docker \
       /var/run/docker.sock

rm -Rf /var/log/unattended-upgrades

# Prevent storing of the MAC address as part of the network
# interface details saved by systemd/udev, and disable support
# for the Predictable (or "consistent") Network Interface Names.
UDEV_RULES=(
    '70-persistent-net.rules'
    '75-persistent-net-generator.rules'
    '80-net-setup-link.rules'
    '80-net-name-slot.rules'
)

for rule in "${UDEV_RULES[@]}"; do
    rm -f "/etc/udev/rules.d/${rule}"
    ln -sf /dev/null "/etc/udev/rules.d/${rule}"
done

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    # Override systemd configuration ...
    rm -f /etc/systemd/network/99-default.link
    ln -sf /dev/null /etc/systemd/network/99-default.link
fi

# Ubuntu 18.04 and newer.
rm -f /etc/netplan/50-cloud-init.yaml

rm -Rf /dev/.udev \
       /var/lib/{dhcp,dhcp3}/* \
       /var/lib/dhclient/*

if [[ -n $AMAZON_EC2 || -n $PROXMOX ]]; then
    # Get rid of this file, alas clout-init will probably
    # create it again automatically so that it can wreck
    # network configuration. These files, sadly cannot be
    # simply a symbolic links to /dev/null, as cloud-init
    # would change permission of the device node to 0644,
    # which is disastrous, every time during the system
    # startup.
    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        rm -f /etc/udev/rules.d/70-persistent-net.rules
    else
        if [[ ! $UBUNTU_VERSION =~ ^(12|14|16).04$ ]]; then
            rm -f /etc/systemd/network/50-cloud-init-eth0.link \
                  /etc/udev/rules.d/70-persistent-net.rules
        else
            rm -f /etc/network/interfaces.d/50-cloud-init.cfg \
                  /etc/systemd/network/50-cloud-init-eth0.link \
                  /etc/udev/rules.d/70-persistent-net.rules

            pushd /etc/network/interfaces.d &>/dev/null
            mknod .null c 1 3
            ln -sf .null 50-cloud-init.cfg
            popd &>/dev/null
        fi
    fi

    pushd /etc/udev/rules.d &>/dev/null
    mknod .null c 1 3
    ln -sf .null 70-persistent-net.rules
    popd &>/dev/null
fi

# Remove surplus locale (and only retain the English one).
mkdir -p /tmp/locale

for directory in /usr/share/locale /usr/share/locale-langpack; do
    for locale in en en@boldquot en_US; do
        LOCALE_PATH="${directory}/${locale}"
        if [[ -d "$LOCALE_PATH" ]]; then
            mv "$LOCALE_PATH" /tmp/locale/
        fi
    done

    rm -Rf ${directory:?}/*

    if [[ -d "$directory" ]]; then
        mv /tmp/locale/* "${directory:?}/"
    fi
done

rm -Rf /tmp/locale

find /etc /var /usr -type f -name '*~' -print0 | \
    xargs -0 rm -f

find /var/log /var/cache /var/lib/apt -type f -print0 | \
    xargs -0 rm -f

find /etc/alternatives /etc/rc[0-9].d -xtype l -print0 | \
    xargs -0 rm -f

if [[ -n $AMAZON_EC2 || -n $PROXMOX ]]; then
    find /etc /root /home -type f -name 'authorized_keys' -print0 | \
        xargs -0 rm -f
else
  # Only the Vagrant user should keep its SSH key. Everything
  # else will either use the user left form the image creation
  # time, or a new key will be fetched and stored by means of
  # cloud-init, etc.
  if ! getent passwd vagrant &> /dev/null; then
    find /etc /root /home -type f -name 'authorized_keys' -print0 | \
        xargs -0 rm -f
  fi
fi

mkdir -p /var/lib/apt/periodic \
         /var/lib/apt/{lists,archives}/partial

chown -R root: /var/lib/apt
chmod -R 755 /var/lib/apt

# Re-create empty directories for system manuals,
# to stop certain package diversions from breaking.
mkdir -p /usr/share/man/man{1..8}

chown -R root: /usr/share/man
chmod -R 755 /usr/share/man

# Newer version of Ubuntu introduce a dedicated
# "_apt" user, which owns the temporary files.
if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    chown _apt: /var/lib/apt/lists/partial
fi

apt-cache gencaches

touch /var/log/{lastlog,wtmp,btmp}

chown root: /var/log/{lastlog,wtmp,btmp}
chmod 644 /var/log/{lastlog,wtmp,btmp}
