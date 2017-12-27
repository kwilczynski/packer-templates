#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly RUBY_FILES='/var/tmp/ruby'

readonly UBUNTU_RELEASE=$(detect_ubuntu_release)

[[ -d $RUBY_FILES ]] || mkdir -p "$RUBY_FILES"

cat <<EOF > /etc/apt/sources.list.d/brightbox-ruby.list
deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu $UBUNTU_RELEASE main
deb-src http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu $UBUNTU_RELEASE main
EOF

chown root: /etc/apt/sources.list.d/brightbox-ruby.list
chmod 644 /etc/apt/sources.list.d/brightbox-ruby.list

if [[ ! -f "${RUBY_FILES}/brightbox-ruby.key" ]]; then
    # Fetch Brightbox's PPA key from the key server.
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C3173AA6
else
    apt-key add "${RUBY_FILES}/brightbox-ruby.key"
fi

# Only refresh packages index from Brightbox's repository.
apt-get --assume-yes update \
    -o Dir::Etc::SourceList='/etc/apt/sources.list.d/brightbox-ruby.list' \
    -o Dir::Etc::SourceParts='-' -o APT::Get::List-Cleanup='0'

# Packages to insall alongside Ruby.
PACKAGES=(
    'ruby-switch'
)

# By default, assume that Ruby 2.3 as a latest stable version.
if [[ -n $RUBY_VERSION ]]; then
    PACKAGES=( $(printf 'ruby%s' "${RUBY_VERSION}") "${PACKAGES[@]}" )
else
    PACKAGES=( ruby2.3 "${PACKAGES[@]}" )
fi

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

# Update RubyGems release to the latest one.
gem update --system

rm -f "${RUBY_FILES}/brightbox-ruby.key"
