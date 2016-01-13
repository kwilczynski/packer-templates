#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# Refresh packages index only when needed.
UPDATE_STAMP='/var/lib/apt/periodic/update-success-stamp'
if [[ ! -f $UPDATE_STAMP ]] || \
   (( $(date +%s) - $(date -r $UPDATE_STAMP +%s) > 900 )); then
    apt-get -y --force-yes update
fi

# Dependencies needed by a lot of Python eggs.
PACKAGES=( python-dev libffi-dev libssl-dev libyaml-dev )

for package in "${PACKAGES[@]}"; do
    apt-get -y --force-yes install $package
done

apt-get -y --force-yes install python-setuptools

# Remove current and rather old version.
apt-get -y --force-yes purge python-pip

easy_install pip
pip install --upgrade pip

for file in /usr/local/bin/pip*; do
    ln -sf $file /usr/bin/${file##*/}
done

# Update look-up table (to get new
# pip binary location).
hash -r

# Remove old version that was only needed to bootstrap
# ourselves.  We prefer more up-to-date one installed
# directly via Python's pip.
apt-get -y --force-yes purge python-setuptools

pip install --upgrade setuptools
pip install --upgrade virtualenv

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

for file in /usr/local/bin/easy_install*; do
    ln -sf $file /usr/bin/${file##*/}
done

hash -r
