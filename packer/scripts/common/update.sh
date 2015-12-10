#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly UBUNTU_RELEASE=$(lsb_release -sc)
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

# Get the major release version only.
readonly UBUNTU_MAJOR_VERSION=$(lsb_release -r | awk '{ print $2 }' | cut -d . -f 1)

readonly COMMON_FILES='/var/tmp/common'

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --tries 2 --wait 1 -O - http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

cat <<'EOF' | tee /etc/apt/apt.conf.d/00trustcdrom
APT
{
    Authentication
    {
        TrustCDROM "false":
    };
};
EOF

chown root:root /etc/apt/apt.conf.d/00trustcdrom
chmod 644 /etc/apt/apt.conf.d/00trustcdrom

cat <<'EOF' | tee /etc/apt/apt.conf.d/15update-stamp
APT
{
    Update
    {
        Post-Invoke-Success
        {
            "touch /var/lib/apt/periodic/update-success-stamp 2>/dev/null || true";
        };
    };
};
EOF

chown root:root /etc/apt/apt.conf.d/15update-stamp
chmod 644 /etc/apt/apt.conf.d/15update-stamp

# Any Amazon EC2 instance can use local packages mirror, but quite often
# such mirrors are backed by an S3 buckets causing performance drop due
# to a known problem outside of the "us-east-1" region when using HTTP
# pipelining for more efficient downloads.
PIPELINE_DEPTH=5
if [[ $AMAZON_EC2 == 'yes' ]]; then
     PIPELINE_DEPTH=0
fi

cat <<EOF | tee /etc/apt/apt.conf.d/99apt-acquire
Acquire
{
    PDiffs "0";

    Retries "3";
    Queue-Mode "access";
    Check-Valid-Until "0";

    ForceIPv4 "1";

    http
    {
        Timeout "120";
        Pipeline-Depth "${PIPELINE_DEPTH}";

        No-cache "0";
        Max-Age "86400";
        No-store "0";
    };

    Languages "none";

    GzipIndexes "1";
    CompressionTypes
    {
        Order
        {
            "gz";
        };
    };

};
EOF

chown root:root /etc/apt/apt.conf.d/99apt-acquire
chmod 644 /etc/apt/apt.conf.d/99apt-acquire

cat <<'EOF' | tee /etc/apt/apt.conf.d/99apt-get
APT
{
    Install-Suggests "0";
    Install-Recommends "0";
    Clean-Installed "0";

    AutoRemove
    {
        SuggestsImportant "0";
    };

    Get
    {
        AllowUnauthenticated "0";
    };
};
EOF

chown root:root /etc/apt/apt.conf.d/99apt-get
chmod 644 /etc/apt/apt.conf.d/99apt-get

cat <<'EOF' | tee /etc/apt/apt.conf.d/99dpkg
DPkg
{
    Options
    {
        "--force-confdef";
        "--force-confnew";
    };
};
EOF

chown root:root /etc/apt/apt.conf.d/99dpkg
chmod 644 /etc/apt/apt.conf.d/99dpkg

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get -y --force-yes clean all
    rm -rf /var/lib/apt/lists
fi

# By default, the "cloud-init" will override the default mirror when run as
# Amazon EC2 instance, thus we replace this file only when building Vagrant
# boxes.
if [[ $AMAZON_EC2 == 'no' ]]; then
    # Render template overriding default list.
    eval "echo \"$(cat /var/tmp/vagrant/sources.list.template)\"" | \
        tee /etc/apt/sources.list

    chown root:root /etc/apt/sources.list
    chmod 644 /etc/apt/sources.list

    rm -f /var/tmp/vagrant/sources.list.template

    apt-get -y --force-yes update
else
    # Allow some grace time for the "cloud-init" to override
    # the default mirror.
    sleep 30
    apt-get -y --force-yes update
fi

export UCF_FORCE_CONFFNEW=1
ucf --purge /boot/grub/menu.lst

apt-get -y --force-yes dist-upgrade

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get -y --force-yes install libreadline-dev dpkg
fi

UBUNTU_BACKPORT='vivid'
if [[ $UBUNTU_VERSION == '12.04' ]]; then
    UBUNTU_BACKPORT='trusty'
fi

KERNEL_PACKAGES=(
    linux-generic-lts-${UBUNTU_BACKPORT}
    linux-image-generic-lts-${UBUNTU_BACKPORT}
    linux-headers-generic-lts-${UBUNTU_BACKPORT}
)

for p in ${KERNEL_PACKAGES[@]}; do
    apt-get -y --force-yes install $p
    apt-mark manual $p
done

apt-get -y --force-yes --no-install-recommends install linux-headers-$(uname -r)

cat <<'EOF' | tee /etc/timezone
Etc/UTC
EOF

chown root:root /etc/timezone
chmod 644 /etc/timezone

dpkg-reconfigure tzdata

cat <<'EOF' | tee /var/lib/locales/supported.d/en
en_US UTF-8
en_US.UTF-8 UTF-8
en_US.Latin1 ISO-8859-1
en_US.Latin9 ISO-8859-15
en_US.ISO-8859-1 ISO-8859-1
en_US.ISO-8859-15 ISO-8859-15
EOF

chown root:root /var/lib/locales/supported.d/en
chmod 644 /var/lib/locales/supported.d/en

dpkg-reconfigure locales

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

cat <<'EOF' | tee /etc/sysctl.d/10-virtual-memory.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF

chown root:root /etc/sysctl.d/10-virtual-memory.conf
chmod 644 /etc/sysctl.d/10-virtual-memory.conf

service procps start

rm -f /etc/resolvconf/resolv.conf.d/head
touch /etc/resolvconf/resolv.conf.d/head

chown root:root /etc/resolvconf/resolv.conf.d/head
chmod 644 /etc/resolvconf/resolv.conf.d/head

NAME_SERVERS=( 8.8.8.8 8.8.4.4 )
if [[ $AMAZON_EC2 == 'yes' ]]; then
    NAME_SERVERS=()
fi

if [[ $PACKER_BUILDER_TYPE =~ ^vmware.*$ ]]; then
    NAME_SERVERS+=( $(route -n | \
        egrep 'UG[ \t]' | \
            awk '{ print $2 }') )
fi

cat <<EOF | sed -e '/^$/d' | tee /etc/resolvconf/resolv.conf.d/tail
$(for s in ${NAME_SERVERS[@]}; do
    echo "nameserver $s"
done)
options timeout:2 attempts:1 rotate single-request-reopen
EOF

chown root:root /etc/resolvconf/resolv.conf.d/tail
chmod 644 /etc/resolvconf/resolv.conf.d/tail

resolvconf -u

apt-get -y --force-yes install libnss-myhostname
apt-mark manual libnss-myhostname

cat <<'EOF' | tee /etc/nsswitch.conf
passwd:         compat
group:          compat
shadow:         compat

hosts:          files myhostname dns
networks:       files

protocols:      files db
services:       files db
ethers:         files db
rpc:            files db

netgroup:       nis
EOF

chown root:root /etc/nsswitch.conf
chmod 644 /etc/nsswitch.conf

update-ca-certificates -v

if [[ $AMAZON_EC2 == 'yes' ]]; then
    cat <<'EOF' | tee /etc/cloud/cloud.cfg.d/90_dpkg.cfg
datasource_list: [ NoCloud, Ec2, None ]
EOF

    dpkg-reconfigure cloud-init
fi

if dpkg -s ntpdate &>/dev/null; then
    # The patch that fixes the race condition between the nptdate
    # and ntpd which occurs during the system startup (more precisely
    # when the network interface goes up and the helper script at
    # "/etc/network/if-up.d/ntpdate" runs).
    PATCH_FILE='ntpdate-if_up_d.patch'

    pushd /etc/network/if-up.d &>/dev/null

    for o in '--dry-run -s -i' '-i'; do
        # Note: This is expected to fail to apply cleanly on a sufficiently
        # up-to-date version the ntpdate package.
        if ! patch -l -t -p0 $o ${COMMON_FILES}/${PATCH_FILE}; then
            break
        fi
    done

    popd &> /dev/null
fi

if [[ -d /etc/dhcp ]]; then
    ln -sf /etc/dhcp /etc/dhcp3
fi

# Make sure that /srv exists.
[[ -d /srv ]] || mkdir -p /srv
chown root:root /srv
chmod 755 /srv
