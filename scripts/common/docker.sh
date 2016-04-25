#!/bin/bash

#
# docker.sh
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

readonly DOCKER_FILES='/var/tmp/docker'

# Get details about the Ubuntu release ...
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')
readonly UBUNTU_RELEASE=$(lsb_release -sc)

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

[[ -d $DOCKER_FILES ]] || mkdir -p $DOCKER_FILES

cat <<EOF > /etc/apt/sources.list.d/docker.list
deb https://apt.dockerproject.org/repo ubuntu-${UBUNTU_RELEASE} main
EOF

chown root: /etc/apt/sources.list.d/docker.list
chmod 644 /etc/apt/sources.list.d/docker.list

if [[ ! -f ${DOCKER_FILES}/docker.key ]]; then
    # Fetch Docker's PPA key from the key server.
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2C52609D
else
    apt-key add ${DOCKER_FILES}/docker.key
fi

# Only refresh packages index from Docker's repository.
apt-get --assume-yes update \
    -o Dir::Etc::SourceList='/etc/apt/sources.list.d/docker.list' \
    -o Dir::Etc::SourceParts='-' -o APT::Get::List-Cleanup='0'

# Dependencies needed by Docker, etc.
PACKAGES=( pciutils procps btrfs-tools xfsprogs git )

if [[ -n $DOCKER_VERSION ]]; then
    # The package name and version is now a little bit awkaward
    # to work with e.g., docker-engine_1.10.0-0~trusty_amd64.deb.
    PACKAGES+=( $(printf 'docker-engine=%s-0~%s' "${DOCKER_VERSION}" "${UBUNTU_RELEASE}") )
else
    PACKAGES+=( docker-engine )
fi

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install $package
done

{
    if [[ $UBUNTU_VERSION == '16.04' ]]; then
        systemctl stop docker
    else
        service docker stop
    fi
} || true

if ! getent group docker &>/dev/null; then
    groupadd --system docker
fi

for user in $(echo "root vagrant ubuntu ${USER}" | tr ' ' '\n' | sort -u); do
    if getent passwd $user &>/dev/null; then
        usermod -aG docker $user
    fi
done

# Add Bash shell completion for Docker and Docker Compose.
for file in docker docker-compose; do
    REPOSITORY='docker'
    if [[ $file =~ ^docker-compose$ ]]; then
      REPOSITORY='compose'
    fi

    if [[ ! -f ${DOCKER_FILES}/${file} ]]; then
        wget --no-check-certificate -O ${DOCKER_FILES}/${file} \
            https://raw.githubusercontent.com/docker/${REPOSITORY}/master/contrib/completion/bash/${file}
    fi

    cp -f ${DOCKER_FILES}/${file} \
          /etc/bash_completion.d/${file}

    chown root: /etc/bash_completion.d/${file}
    chmod 644 /etc/bash_completion.d/${file}
done

# Disable IPv6 in Docker.
sed -i -e \
    's/.*DOCKER_OPTS="\(.*\)"/DOCKER_OPTS="\1 --ipv6=false"/g' \
    /etc/default/docker

# We can install the docker-compose pip, but it has to be done
# under virtualenv as it has specific version requirements on
# its dependencies, often causing other things to break.
virtualenv /opt/docker-compose
pushd /opt/docker-compose &>/dev/null

# Make sure to switch into the virtualenv.
. /opt/docker-compose/bin/activate

# This is needed, as virtualenv by default will install
# some really old version (e.g. 12.0.x, etc.), sadly.
pip install --upgrade setuptools

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

# The "--install-scripts" option is to make sure that binary
# will be placed in the system-wide directory, rather than
# inside the virtualenv environment only.
if [[ -n $DOCKER_COMPOSE_VERSION ]]; then
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        docker-compose==${DOCKER_COMPOSE_VERSION}
else
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        docker-compose
fi

deactivate
popd &>/dev/null

hash -r

ln -sf /usr/local/bin/docker-compose \
       /usr/bin/docker-compose

if [[ -f /usr/local/bin/wsdump.py ]]; then
    ln -sf /usr/local/bin/wsdump.py \
           /usr/local/bin/wsdump
fi

hash -r

KERNEL_OPTIONS=( swapaccount=1 cgroup_enable=memory )
readonly KERNEL_OPTIONS=$(echo "${KERNEL_OPTIONS[@]}")

# Support both grub and grub2 style configuration.
if grub-install --version | egrep -q '(1.9|2.0).+'; then
    # Remove any repeated (de-duplicate) Kernel options.
    OPTIONS=$(sed -e \
        "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ${KERNEL_OPTIONS}\"/" \
        /etc/default/grub | \
            grep -E '^GRUB_CMDLINE_LINUX=' | \
                sed -e 's/GRUB_CMDLINE_LINUX=\"\(.*\)\"/\1/' | \
                    tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    sed -i -e \
        "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"${OPTIONS}\"/" \
        /etc/default/grub
else
    # Remove any repeated (de-duplicate) Kernel options.
    OPTIONS=$(sed -e \
        "s/^#\sdefoptions=\(.*\)/# defoptions=\1 ${KERNEL_OPTIONS}/" \
        /boot/grub/menu.lst | \
            grep -E '^#\sdefoptions=' | \
                sed -e 's/.*defoptions=//' | \
                    tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    sed -i -e \
        "s/^#\sdefoptions=.*/# defoptions=${OPTIONS}/" \
        /boot/grub/menu.lst
fi

if [[ -f /etc/default/ufw ]]; then
    sed -i -e \
        's/DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/g' \
        /etc/default/ufw
fi

grep 'docker' /proc/mounts | awk '{ print length, $2 }' | \
    sort -gr | cut -d' ' -f2- | xargs umount -l -f 2> /dev/null || true

# This would normally be on a separate volume,
# and most likely formatted to use "btrfs".
for directory in /srv/docker /var/lib/docker; do
  [[ -d $directory ]] || mkdir -p $directory

  rm -rf ${directory}/*

  chown root: $directory
  chmod 755 $directory
done

# A bind-mount for the Docker root directory.
cat <<'EOS' | sed -e 's/\s\+/\t/g' >> /etc/fstab
/srv/docker /var/lib/docker none bind 0 0
EOS

rm -f ${DOCKER_FILES}/docker{.key,-compose}
