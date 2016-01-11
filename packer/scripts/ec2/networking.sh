#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly EC2_FILES='/var/tmp/ec2'

[[ -d $EC2_FILES ]] || mkdir -p $EC2_FILES

# The version 2.16.4 is currently the recommended version.
INTEL_DRIVER='ixgbevf-2.16.4.tar.gz'
if [[ ! -f ${EC2_FILES}/${INTEL_DRIVER} ]]; then
    wget --no-check-certificate -O ${EC2_FILES}/${INTEL_DRIVER} \
        https://downloadmirror.intel.com/18700/eng/${INTEL_DRIVER}
fi

# Dependencies needed to compile the Intel network card driver.
PACKAGES=(
    build-essential dkms
    linux-headers-$(uname -r)
)

for package in "${PACKAGES[@]}"; do
    apt-get -y --force-yes install $package
done

hash -r

if [[ ! -d /usr/src ]]; then
    mkdir -p /usr/src
    chown root: /usr/src
    chmod 755 /usr/src
fi

tar -zxf ${EC2_FILES}/${INTEL_DRIVER} -C /usr/src

# Extract directory name from the source code archive name.
SOURCE_DIRECTORY=/usr/src/${INTEL_DRIVER%%.tar.gz}

pushd $SOURCE_DIRECTORY &>/dev/null

cat <<'EOF' | tee ${SOURCE_DIRECTORY}/dkms.conf
PACKAGE_NAME="ixgbevf"
PACKAGE_VERSION="2.16.4"

AUTOINSTALL="yes"
REMAKE_INITRD="yes"

BUILT_MODULE_LOCATION[0]="src/"
BUILT_MODULE_NAME[0]="ixgbevf"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ixgbevf"

CLEAN="make -C src/ clean"
MAKE="make -C src/ BUILD_KERNEL=${kernelver}"
EOF

popd &> /dev/null

chown root: ${SOURCE_DIRECTORY}/dkms.conf
chmod 644 ${SOURCE_DIRECTORY}/dkms.conf

# Manage the Intel network card driver with dkms ...
for option in add build install; do
    dkms $option -m ixgbevf -v 2.16.4
done

# Make sure to limit the number of interrupts that the adapter (the
# underlying Intel network card) will generate for incoming packets.
cat <<'EOF' | tee /etc/modprobe.d/ixgbevf.conf
options ixgbevf InterruptThrottleRate=1,1,1,1,1,1,1,1
EOF

chown root: /etc/modprobe.d/ixgbevf.conf
chmod 644 /etc/modprobe.d/ixgbevf.conf

rm -f ${EC2_FILES}/${INTEL_DRIVER}
