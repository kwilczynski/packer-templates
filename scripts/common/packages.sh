#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)
readonly AMAZON_EC2=$(detect_amazon_ec2 && echo 'true')

# A list of common packages to be installed.
PACKAGES=(
    'ntp'
    'wget'
    'curl'
    'vim'
    'haveged'
    'iptables'
    'irqbalance'
    'heirloom-mailx'
    'software-properties-common'
    'python-software-properties'
    'apt-transport-https'
)

apt_get_update

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

{
    if [[ $UBUNTU_VERSION == '16.04' ]]; then
        systemctl stop ntp
    else
        service ntp stop
    fi
} || true

# Force IPv4 only, and enable slew mode to handle the clock
# moving backwards in one large increment, for example in a
# case of a leap-second, etc.
sed -i -e \
    "s/.*NTPD_OPTS='\(.*\)'/NTPD_OPTS='-x \1 -4'/g" \
    /etc/default/ntp

# Makes time sync more aggressively in a VM. See
# http://kb.vmware.com/kb/1006427 for more details.
sed -i -e \
    '/.*restrict -6.*$/d;/.*restrict ::1$/d;1a\\ntinker panic 0' \
    /etc/ntp.conf

# Disable the monitoring facility to prevent attacks using ntpdc monlist
# command when default restrict does not include the noquery flag. See
# https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2013-5211 for more
# details.
sed -i -e \
    '/tinker panic.*/a disable monitor' \
    /etc/ntp.conf

if [[ -n $AMAZON_EC2 ]]; then
    sed -i -e '/server.*\.ubuntu\.pool\.ntp\.org/ s/\.ubuntu\.\(.*\)\s\?/\.amazon\.\1\ iburst/g' \
        /etc/ntp.conf
else
    sed -i -e \
        '/server.*\.ubuntu\.pool\.ntp\.org/ s/ubuntu\.\(.*\)/\1 iburst/' \
        /etc/ntp.conf
fi

update-alternatives --set editor /usr/bin/vim.basic
