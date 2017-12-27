#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

# Dependencies needed by a lot of Python eggs.
PACKAGES=(
    'python-dev'
    'libffi-dev'
    'libssl-dev'
    'libyaml-dev'
)

apt_get_update

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

apt-get --assume-yes install python-setuptools

# Remove current and rather old version.
apt-get --assume-yes purge python-pip

# The easy_install package available in Ubuntu 12.04 is too old,
# and still uses old HTTP mirror which is no longer supported
# by PyPi for retrieving an index. We temporarily change it to
# facilitate installation.
if [[ $UBUNTU_VERSION == '12.04' ]]; then
    eval HOME_DIRECTORY="~${USER}"

    cat <<'EOF' > "${HOME_DIRECTORY}/.pydistutils.cfg"
[easy_install]
index-url = https://pypi.python.org/simple
EOF

    easy_install pip

    rm -f "${HOME_DIRECTORY}/.pydistutils.cfg"
else
    easy_install pip
fi

pip install --upgrade pip

for file in /usr/local/bin/pip*; do
    ln -sf "$file" "/usr/bin/${file##*/}"
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
    ln -sf "$file" "/usr/bin/${file##*/}"
done
