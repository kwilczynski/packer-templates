#!/bin/bash

#
# python-pip.sh
#
# Copyright 2016-2017 Krzysztof Wilczynski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e
set -o pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

# Refresh packages index only when needed.
UPDATE_STAMP='/var/lib/apt/periodic/update-success-stamp'
if [[ ! -f $UPDATE_STAMP ]] || \
   (( $(date +%s) - $(date -r $UPDATE_STAMP +%s) > 900 )); then
    apt-get --assume-yes update
fi

# Dependencies needed by a lot of Python eggs.
PACKAGES=( python-dev libffi-dev libssl-dev libyaml-dev )

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install $package
done

apt-get --assume-yes install python-setuptools

# Remove current and rather old version.
apt-get --assume-yes purge python-pip

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
apt-get --assume-yes purge python-setuptools

pip install --upgrade setuptools
pip install --upgrade virtualenv

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

for file in /usr/local/bin/easy_install*; do
    ln -sf $file /usr/bin/${file##*/}
done
