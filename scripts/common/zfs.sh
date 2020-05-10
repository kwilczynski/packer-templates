#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly ZFS_FILES='/var/tmp/zfs'

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

[[ -d $ZFS_FILES ]] || mkdir -p "$ZFS_FILES"

apt_get_update

# ZFS Native package name for Ubuntu 16.04 or newer...
ZFS_PACKAGE='zfsutils-linux'

# Ubuntu 14.04 requires a PPA to be added in order to have a native ZFS support.
if [[ $UBUNTU_VERSION == '14.04' ]]; then
    cat <<EOF > /etc/apt/sources.list.d/zfs-native.list
deb http://ppa.launchpad.net/zfs-native/stable/ubuntu trusty main
deb-src http://ppa.launchpad.net/zfs-native/stable/ubuntu trusty main
EOF

    if [[ ! -f "${ZFS_FILES}/zfs-native.key" ]]; then
        # Fetch Canonical's ZFS Native PPA key from the key server.
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys F6B0FC61
    else
        apt-key add "${ZFS_FILES}/zfs-native.key"
    fi

    apt-get --assume-yes update \
        -o Dir::Etc::SourceList='/etc/apt/sources.list.d/zfs-native.list' \
        -o Dir::Etc::SourceParts='-' -o APT::Get::List-Cleanup='0'

    ZFS_PACKAGE='ubuntu-zfs'
fi

apt-get --assume-yes install \
    "$ZFS_PACKAGE"

cat <<'EOF' > /etc/sysfs.d/zfs.conf
module/zfs/parameters/zfs_vdev_scheduler = noop
module/zfs/parameters/zfs_read_chunk_size = 1310720
module/zfs/parameters/zfs_prefetch_disable = 1
EOF

chown root: /etc/sysfs.d/zfs.conf
chmod 644 /etc/sysfs.d/zfs.conf
rm -f "${ZFS_FILES}/zfs-native.list"
