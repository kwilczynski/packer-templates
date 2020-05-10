#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly OPENSSL_FILES='/var/tmp/openssl'
readonly UBUNTU_RELEASE=$(detect_ubuntu_release)

[[ -d $OPENSSL_FILES ]] || mkdir -p "$OPENSSL_FILES"

cat <<EOF > /etc/apt/sources.list.d/ondrej-apache2.list
deb http://ppa.launchpad.net/ondrej/apache2/ubuntu $UBUNTU_RELEASE main
deb-src http://ppa.launchpad.net/ondrej/apache2/ubuntu $UBUNTU_RELEASE main
EOF

chown root: /etc/apt/sources.list.d/ondrej-apache2.list
chmod 644 /etc/apt/sources.list.d/ondrej-apache2.list

if [[ ! -f "${OPENSSL_FILES}/ondrej.key" ]]; then
    # Fetch Ondřej Surý's PPA key from the key server.
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys E5267A6C
else
    apt-key add "${OPENSSL_FILES}/ondrej.key"
fi

# Only refresh packages index from Ondřej's Apache2 repository.
apt-get --assume-yes update \
    -o Dir::Etc::SourceList='/etc/apt/sources.list.d/ondrej-apache2.list' \
    -o Dir::Etc::SourceParts='-' -o APT::Get::List-Cleanup='0'

# Ondřej's Apache2 repository provides more up-to-date version
# of the OpenSSL library, compared to an old version available
# by default in Ubuntu.
PACKAGES=(
    'openssl'
    'libssl1.1'
)

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

rm -f "${OPENSSL_FILES}/ondrej.key"
