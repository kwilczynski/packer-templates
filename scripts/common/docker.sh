#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly DOCKER_FILES='/var/tmp/docker'

readonly UBUNTU_RELEASE=$(detect_ubuntu_release)
readonly UBUNTU_VERSION=$(detect_ubuntu_version)

readonly AMAZON_EC2=$(detect_amazon_ec2 && echo 'true')

[[ -d $DOCKER_FILES ]] || mkdir -p "$DOCKER_FILES"

# Old package repository has been shut down, see:
#  https://www.docker.com/blog/changes-dockerproject-org-apt-yum-repositories/
cat <<EOF > /etc/apt/sources.list.d/docker.list
$(if [[ $UBUNTU_VERSION == '12.04' ]]; then
    echo "deb [arch=amd64] https://ftp.yandex.ru/mirrors/docker ubuntu-${UBUNTU_RELEASE} main"
else
    if [[ $UBUNTU_VERSION =~ ^(14|16|18).04$ ]]; then
        echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${UBUNTU_RELEASE} stable"
    else
        # Starting from 20.04, Docker no long provides packages from their repository.
        echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    fi
fi)
EOF

chown root: /etc/apt/sources.list.d/docker.list
chmod 644 /etc/apt/sources.list.d/docker.list

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    if [[ ! -f "${DOCKER_FILES}/12.04/docker.key" ]]; then
        # Download key directly from Docker project.
        wget -O "${DOCKER_FILES}/docker.key" \
            "https://ftp.yandex.ru/mirrors/docker/gpg"
    else
        cp -f "${DOCKER_FILES}/12.04/docker.key" \
              "${DOCKER_FILES}/docker.key"
    fi
else
    if [[ ! -f "${DOCKER_FILES}/docker.key" ]]; then
        # Download key directly from Docker project.
        wget -O "${DOCKER_FILES}/docker.key" \
            "https://download.docker.com/linux/ubuntu/gpg"
    fi
fi

apt-key add "${DOCKER_FILES}/docker.key"

apt_get_update

# Only refresh packages index from Docker's repository.
apt-get --assume-yes update \
    -o Dir::Etc::SourceList='/etc/apt/sources.list.d/docker.list' \
    -o Dir::Etc::SourceParts='-' -o APT::Get::List-Cleanup='0'

# Dependencies needed by Docker, etc.
PACKAGES=(
    'pciutils'
    'procps'
    'xfsprogs'
    'git'
)

if [[ $UBUNTU_VERSION =~ ^(12|14|16|18).04$ ]]; then
    PACKAGES+=(
        'btrfs-tools'
    )
else
    # Starting from 20.04, btrfs-progs is no longer a virtual package.
    PACKAGES+=(
        'btrfs-progs'
    )
fi

DOCKER_PACKAGE='docker-ce'
if [[ $UBUNTU_VERSION == '12.04' ]]; then
    DOCKER_PACKAGE='docker-engine'
fi

if [[ -n $DOCKER_VERSION ]]; then
    # The package name and version is now a little bit awkaward to work
    # which is why we rely on wildcard match for a given version of Docker,
    # for example:
    # - Old packages e.g., docker-engine_17.05.0~ce-0~ubuntu-trusty_amd64.deb;
    # - New packages e.g., docker-ce_17.12.0~ce-0~ubuntu_amd64.deb.
    PACKAGES+=( $(printf '%s=%s~ce*' "$DOCKER_PACKAGE" "$DOCKER_VERSION") )
else
    PACKAGES+=( "$DOCKER_PACKAGE" )
fi

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

{
    if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
        systemctl stop docker
    else
        service docker stop
    fi
} || true

# Do not start Docker automatically when
# running on Amazon EC2, as it might be
# desirable to relocate the /var/lib/docker
# on a separate mount point, etc.
if [[ -n $AMAZON_EC2 ]]; then
    {
        if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
            systemctl disable docker
        else
            update-rc.d -f docker disable
            # Disable when using upstart.
            echo 'manual' | sudo tee /etc/init/docker.override
        fi
    } || true
fi

if ! getent group docker &>/dev/null; then
    groupadd --system docker
fi

for user in $(echo "root vagrant ubuntu ${USER}" | tr ' ' '\n' | sort -u); do
    if getent passwd "$user" &>/dev/null; then
        usermod -a -G docker "$user"
    fi
done

# Add Bash shell completion for Docker and Docker Compose.
for file in docker docker-compose; do
    REPOSITORY='docker-ce'
    FILE_PATH='components/cli/contrib/completion/bash'
    if [[ $file =~ ^docker-compose$ ]]; then
        REPOSITORY='compose'
        FILE_PATH='contrib/completion/bash'
    fi

    if [[ ! -f "${DOCKER_FILES}/${file}" ]]; then
        wget -O "${DOCKER_FILES}/${file}" \
            "https://raw.githubusercontent.com/docker/${REPOSITORY}/master/${FILE_PATH}/${file}"
    fi

    cp -f "${DOCKER_FILES}/${file}" \
          "/etc/bash_completion.d/${file}"

    chown root: "/etc/bash_completion.d/${file}"
    chmod 644 "/etc/bash_completion.d/${file}"
done

sed -i -e \
    's/.*DOCKER_OPTS="\(.*\)"/DOCKER_OPTS="--config-file=\/etc\/docker\/daemon.json"/g' \
    /etc/default/docker

# Shouldn't the package create this?
if [[ ! -d /etc/docker ]]; then
    mkdir -p /etc/docker
    chown root: /etc/docker
    chmod 755 /etc/docker
fi

# For now, the "userns-remap" option is disabled,
# since it breaks almost everything at the moment.
cat <<EOF > /etc/docker/daemon.json
{
  "debug": false,
$(if [[ $UBUNTU_VERSION == '12.04' ]]; then
    # No support for overlay2 file system in the
    # Linux kernel on older versions of Ubuntu.
    cat <<'EOS'
  "graph": "/var/lib/docker",
  "storage-driver": "aufs",
EOS
else
    cat <<'EOS'
  "data-root": "/var/lib/docker",
  "storage-driver": "overlay2",
EOS
fi)
  "ipv6": false,
  "dns": [
    "1.1.1.1",
    "8.8.8.8",
    "4.2.2.2"
  ],
  "icc": false,
  "live-restore": true,
  "userland-proxy": false,
  "experimental": true
}
EOF

chown root: /etc/docker/daemon.json
chmod 644 /etc/docker/daemon.json

# We can install the docker-compose pip, but it has to be done
# under virtualenv as it has specific version requirements on
# its dependencies, often causing other things to break.
virtualenv /opt/docker-compose
pushd /opt/docker-compose &>/dev/null

# Make sure to switch into the virtualenv.
. /opt/docker-compose/bin/activate

# This is needed, as virtualenv by default will install
# some really old version (e.g. 12.0.x, etc.), sadly.
if [[ $UBUNTU_VERSION =~ '12.04' ]]; then
    pip install --upgrade setuptools==43.0.0
else
    pip install --upgrade setuptools
fi

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

# The "--install-scripts" option is to make sure that binary
# will be placed in the system-wide directory, rather than
# inside the virtualenv environment only.
if [[ -n $DOCKER_COMPOSE_VERSION ]]; then
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        docker-compose=="${DOCKER_COMPOSE_VERSION}"
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

KERNEL_OPTIONS=(
    'cgroup_enable=memory'
    'swapaccount=1'
)

# Support both grub and grub2 style configuration.
if detect_grub2; then
    # Remove any repeated (de-duplicate) Kernel options.
    OPTIONS=$(sed -e \
        "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ${KERNEL_OPTIONS[*]}\"/" \
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
        "s/^#\sdefoptions=\(.*\)/# defoptions=\1 ${KERNEL_OPTIONS[*]}/" \
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
    sort -g -r | cut -d' ' -f2- | xargs umount -l -f 2> /dev/null || true

# This would normally be on a separate volume,
# and most likely formatted to use "btrfs".
for directory in /srv/docker /var/lib/docker; do
    [[ -d $directory ]] || mkdir -p "$directory"

    rm -Rf ${directory:?}/*

    chown root: "$directory"
    chmod 755 "$directory"
done

# A bind-mount for the Docker root directory.
cat <<'EOS' | sed -e 's/\s\+/\t/g' >> /etc/fstab
/srv/docker /var/lib/docker none bind 0 0
EOS

rm -f ${DOCKER_FILES}/docker{.key,-compose}
