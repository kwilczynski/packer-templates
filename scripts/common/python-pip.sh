#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly COMMON_FILES='/var/tmp/common'

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

[[ -d $COMMON_FILES ]] || mkdir -p "$COMMON_FILES"

# Dependencies needed by a lot of Python eggs.
PACKAGES=(
    'libffi-dev'
    'libssl-dev'
    'libyaml-dev'
)

if [[ $UBUNTU_VERSION =~ ^(12|14|16).04$ ]]; then
    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        PACKAGES+=(
            'python-dev'
            'python-setuptools'
        )
    else
        PACKAGES+=(
            'python-dev'
            'python-setuptools'
            'python3-dev'
            'python3-setuptools'
            'python3-pkg-resources'
        )
    fi
else
    PACKAGES+=(
        'python3-dev'
        'python3-distutils'
    )
fi

apt_get_update

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

if [[ $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    # Remove current and rather old version.
    PACKAGES=(
        'python-pip'
        'python3-pip'
    )

    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        PACKAGES=(
            'python-pip'
        )
    fi

    for package in "${PACKAGES[@]}"; do
        apt-get --assume-yes purge "$package"
    done
fi

if [[ $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
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
    fi

    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        easy_install pip
    else
        for suffix in '' '3'; do
            # Version 19.0 and newer removed support for Python 3.4,
            # and on older version of Ubuntu it's a pure nightmare
            # to support multiple versions installed when everything
            # depends on Python 3.4 solely. Version 18.0 and newer
            # removed support for Python 3.3.
            "easy_install${suffix}" pip==18.1
        done
    fi

    rm -f "${HOME_DIRECTORY}/.pydistutils.cfg"
else
    if [[ ! -f "${COMMON_FILES}/get-pip.py" ]]; then
        # Fetch get-pip.py script from the PyPA project directly.
        wget -O "${COMMON_FILES}/get-pip.py" \
            https://bootstrap.pypa.io/get-pip.py
    fi

    for suffix in '' '3'; do
        if command -v "python${suffix}" >/dev/null; then
            "python${suffix}" "${COMMON_FILES}/get-pip.py"
        fi
    done

    rm -f "${COMMON_FILES}/get-pip.py"
fi

# Make the default pip to be from Python 2.7,
# which would be the default, if present.
if [[ -f /usr/local/bin/pip2.7 ]]; then
    rm -f /usr/local/bin/pip

    cp -f /usr/local/bin/pip2.7 \
          /usr/local/bin/pip
fi

for file in /usr/local/bin/pip*; do
    ln -sf "$file" "/usr/bin/${file##*/}"
done

# Update look-up table (to get new
# pip binary location).
hash -r

# Resolve the "InsecurePlatformWarning" warning.
if [[ $UBUNTU_VERSION == '12.04' ]]; then
    pip install --upgrade ndg-httpsclient
else
    for suffix in '' '3'; do
        "pip${suffix}" install --upgrade \
            ndg-httpsclient
    done
fi

# Remove old version that was only needed to bootstrap
# ourselves.  We prefer more up-to-date one installed
# directly via Python's pip.
PACKAGES=(
    'python-setuptools'
    'python3-setuptools'
)

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    PACKAGES=(
        'python-setuptools'
    )
fi

if [[ ! $UBUNTU_VERSION =~ ^(12|14|16|18).04$ ]]; then
    # Starting from 20.14, cloud-init package has
    # dependencies on the new Python 3 toolchain,
    # thus we need to keep python3-setuptools even
    # if we don't really need to.
    if dpkg -s cloud-init >/dev/null; then
        PACKAGES=()
    fi
fi

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes purge "$package"
done

if [[ $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    pip install --upgrade six --ignore-installed six
    pip install --upgrade setuptools

    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        # The virtualenv version 20.0.0 or newer appears to
        # be broken, as the pyconfig.h file won't be made
        # available.
        pip install --upgrade virtualenv==16.7.10
    else
        pip install --upgrade virtualenv
    fi
else
    for suffix in '' '3'; do
        "pip${suffix}" install --upgrade setuptools
        "pip${suffix}" install --upgrade virtualenv
    done
fi

for file in /usr/local/bin/easy_install*; do
    ln -sf "$file" "/usr/bin/${file##*/}"
done
