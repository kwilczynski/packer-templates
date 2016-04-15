#!/bin/bash

#
# ruby.sh
#
# Copyright 2016 Krzysztof Wilczynski
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

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly RUBY_FILES='/var/tmp/ruby'
readonly UBUNTU_RELEASE=$(lsb_release -sc)

[[ -d $RUBY_FILES ]] || mkdir -p $RUBY_FILES

cat <<EOF > /etc/apt/sources.list.d/brightbox-ruby.list
deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu ${UBUNTU_RELEASE} main
deb-src http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu ${UBUNTU_RELEASE} main
EOF

chown root: /etc/apt/sources.list.d/brightbox-ruby.list
chmod 644 /etc/apt/sources.list.d/brightbox-ruby.list

if [[ ! -f ${RUBY_FILES}/brightbox-ruby.key ]]; then
    # Fetch Brightbox's PPA key from the key server.
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C3173AA6
else
    apt-key add ${RUBY_FILES}/brightbox-ruby.key
fi

# Only refresh packages index from Brightbox's repository.
apt-get -y --force-yes update \
    -o Dir::Etc::SourceList='/etc/apt/sources.list.d/brightbox-ruby.list' \
    -o Dir::Etc::SourceParts='-' -o APT::Get::List-Cleanup='0'

# Packages to insall alongside Ruby.
PACKAGES=( ruby-switch )

# By default, assume that Ruby 2.3 as a latest stable version.
if [[ -n $RUBY_VERSION ]]; then
    PACKAGES=( $(printf 'ruby%s' "${RUBY_VERSION}") "${PACKAGES[@]}" )
else
    PACKAGES=( ruby2.3 "${PACKAGES[@]}" )
fi

for package in "${PACKAGES[@]}"; do
    apt-get -y --force-yes install $package
done

# Update RubyGems release to the latest one.
gem update --system

rm -f ${RUBY_FILES}/brightbox-ruby.key
