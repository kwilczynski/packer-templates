#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly EC2_FILES='/var/tmp/ec2'

[[ -d $EC2_FILES ]] || mkdir -p "$EC2_FILES"

# The version 4.2.1 is currently the recommended version.
SRIOV_DRIVER='ixgbevf-4.2.1.tar.gz'
if [[ -n $SRIOV_DRIVER_VERSION ]]; then
    SRIOV_DRIVER="ixgbevf-${SRIOV_DRIVER_VERSION}.tar.gz"
fi

ENA_DRIVER='ena_linux_1.3.0.tar.gz'
if [[ -n $ENA_DRIVER_VERSION ]]; then
    ENA_DRIVER="ena_linux_${ENA_DRIVER_VERSION}.tar.gz"
fi

# Extract version number from the file name.
SRIOV_DRIVER_VERSION=$(echo "$SRIOV_DRIVER" | sed -e \
    's/[^0-9.]*\([0-9.]\+\)\.tar\.gz/\1/')

ENA_DRIVER_VERSION=$(echo "$ENA_DRIVER" | sed -e \
    's/[^0-9.]*\([0-9.]\+\)\.tar\.gz/\1/')

if [[ ! -f ${EC2_FILES}/${SRIOV_DRIVER} ]]; then
    wget -O "${EC2_FILES}/${SRIOV_DRIVER}" \
        "http://sourceforge.net/projects/e1000/files/ixgbevf%20stable/${SRIOV_DRIVER_VERSION}/${SRIOV_DRIVER}"
fi

if [[ ! -f ${EC2_FILES}/${ENA_DRIVER} ]]; then
    wget -O "${EC2_FILES}/${ENA_DRIVER}" \
        "https://github.com/amzn/amzn-drivers/archive/${ENA_DRIVER}"
fi

# Dependencies needed to compile the Intel network card driver.
PACKAGES=(
    'build-essential'
    "linux-headers-$(uname -r)"
    'dkms'
)

apt_get_update

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

hash -r

if [[ ! -d /usr/src ]]; then
    mkdir -p /usr/src
    chown root: /usr/src
    chmod 755 /usr/src
fi

tar -zxf "${EC2_FILES}/${SRIOV_DRIVER}" -C /usr/src

# Extract directory name from the source code archive name.
SOURCE_DIRECTORY="/usr/src/${SRIOV_DRIVER//.tar.gz/}"

pushd "$SOURCE_DIRECTORY" &>/dev/null

# WARNING: A variable needs to be escaped there!
cat <<EOF > "${SOURCE_DIRECTORY}/dkms.conf"
PACKAGE_NAME="ixgbevf"
PACKAGE_VERSION="${SRIOV_DRIVER_VERSION}"

AUTOINSTALL="yes"
REMAKE_INITRD="yes"

BUILT_MODULE_LOCATION[0]="src/"
BUILT_MODULE_NAME[0]="ixgbevf"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ixgbevf"

CLEAN="cd src; make clean"
MAKE="cd src; make BUILD_KERNEL=\${kernelver}"
EOF

popd &> /dev/null

# Fix /usr/src/ixgbevf-4.2.1/src/kcompat.h:755:2: error: #error UTS_UBUNTU_RELEASE_ABI is too large...
# See: https://stackoverflow.com/a/44833347
sed -i -e \
    's/#if UTS_UBUNTU_RELEASE_ABI > 255/#if UTS_UBUNTU_RELEASE_ABI > 99255/' \
    "/usr/src/ixgbevf-${SRIOV_DRIVER_VERSION}/src/kcompat.h"

chown root: "${SOURCE_DIRECTORY}/dkms.conf"
chmod 644 "${SOURCE_DIRECTORY}/dkms.conf"

# Manage the Intel network card driver with dkms ...
for option in add build install; do
    dkms "$option" -m ixgbevf -v "$SRIOV_DRIVER_VERSION"
done

# Make sure to limit the number of interrupts that the adapter (the
# underlying Intel network card) will generate for incoming packets.
cat <<'EOF' > /etc/modprobe.d/ixgbevf.conf
options ixgbevf InterruptThrottleRate=1,1,1,1,1,1,1,1
EOF

chown root: /etc/modprobe.d/ixgbevf.conf
chmod 644 /etc/modprobe.d/ixgbevf.conf

tar -zxf "${EC2_FILES}/${ENA_DRIVER}" -C /usr/src

# Extract directory name from the source code archive name.
SOURCE_DIRECTORY="/usr/src/ena-${ENA_DRIVER_VERSION}"

if [[ -d "/usr/src/amzn-drivers-ena_linux_${ENA_DRIVER_VERSION}" ]]; then
    mv "/usr/src/amzn-drivers-ena_linux_${ENA_DRIVER_VERSION}" "$SOURCE_DIRECTORY"
fi

pushd "$SOURCE_DIRECTORY" &>/dev/null

# WARNING: A variable needs to be escaped there!
cat <<EOF > "${SOURCE_DIRECTORY}/dkms.conf"
PACKAGE_NAME="ena"
PACKAGE_VERSION="${ENA_DRIVER_VERSION}"

AUTOINSTALL="yes"
REMAKE_INITRD="yes"

BUILT_MODULE_LOCATION[0]="kernel/linux/ena"
BUILT_MODULE_NAME[0]="ena"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ena"

CLEAN="cd kernel/linux/ena; make clean"
MAKE="cd kernel/linux/ena; make BUILD_KERNEL=\${kernelver}"
EOF

popd &> /dev/null

chown root: "${SOURCE_DIRECTORY}/dkms.conf"
chmod 644 "${SOURCE_DIRECTORY}/dkms.conf"

# Manage the Intel network card driver with dkms ...
for option in add build install; do
    dkms "$option" -m ena -v "$ENA_DRIVER_VERSION"
done

rm -f "${EC2_FILES}/${SRIOV_DRIVER:?}" \
      "${EC2_FILES}/${ENA_DRIVER:?}"
