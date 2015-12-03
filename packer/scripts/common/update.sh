#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly UBUNTU_RELEASE=$(lsb_release -sc)
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

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

cat <<'EOF' | tee /etc/apt/apt.conf.d/99apt-acquire
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
        Pipeline-Depth "5";

        No-cache "0";
        Max-Age "86400";
        No-store "0";
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

eval "echo \"$(cat /var/tmp/common/sources.list.template)\"" | \
    tee /etc/apt/sources.list

chown root:root /etc/apt/sources.list
chmod 644 /etc/apt/sources.list

rm -f /var/tmp/common/sources.list.template

apt-get -y --force-yes update

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get -y --force-yes install linux-generic-lts-trusty
    apt-get -y --force-yes install linux-image-generic-lts-trusty
    apt-get -y --force-yes install linux-headers-generic-lts-trusty
fi

apt-get -y --force-yes --no-install-recommends install linux-headers-$(uname -r)

export UCF_FORCE_CONFFNEW=1
ucf --purge /boot/grub/menu.lst

apt-get -y --force-yes dist-upgrade

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get -y --force-yes install libreadline-dev dpkg
fi

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

# Make sure that /srv exists.
[[ -d /srv ]] || mkdir -p /srv
chown root:root /srv
chmod 755 /srv
