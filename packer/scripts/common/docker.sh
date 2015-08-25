#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly DOCKER_FILES='/var/tmp/docker'

[[ -d $DOCKER_FILES ]] || mkdir -p $DOCKER_FILES

cat <<'EOF' | tee /etc/apt/sources.list.d/docker.list
deb https://get.docker.com/ubuntu docker main
EOF

chown root:root /etc/apt/sources.list.d/docker.list
chmod 644 /etc/apt/sources.list.d/docker.list

if [[ ! -f ${DOCKER_FILES}/docker.key ]]; then
    wget --no-check-certificate -O ${DOCKER_FILES}/docker.key \
        https://get.docker.com/gpg
fi

apt-key add ${DOCKER_FILES}/docker.key

apt-get -y --force-yes install apt-transport-https software-properties-common
apt-get -y --force-yes update

apt-get -y --force-yes install build-essential pkg-config swig
apt-get -y --force-yes install libyaml-0-2 libgmp10
apt-get -y --force-yes install python-dev libyaml-dev libgmp-dev libssl-dev
apt-get -y --force-yes install procps pciutils
apt-get -y --force-yes install btrfs-tools
apt-get -y --force-yes install git

PACKAGES=(
    pkg-config swig
    software-properties-common
    libyaml-0-2 libgmp10 libzmq3
    btrfs-tools
    pciutils procps
    git
)

if [[ -n $DOCKER_VERSION ]]; then
    PACKAGES+=( lxc-docker-${DOCKER_VERSION} )
else
    PACKAGES+=( lxc-docker )
fi

for p in ${PACKAGES[@]}; do
    if [[ $(dpkg -s $p 2>/dev/null) ]]; then
        apt-mark manual $p
    fi
done

PACKAGE_NAME='lxc-docker'
if [[ -n $DOCKER_VERSION ]]; then
    PACKAGE_NAME="lxc-docker-${DOCKER_VERSION}"
fi

apt-get -y --force-yes --no-install-recommends install $PACKAGE_NAME

service docker stop || true

if ! getent group docker &>/dev/null; then
    groupadd --system docker
fi

for u in $(echo "root vagrant ubuntu ${USER}" | tr ' ' '\n' | sort -u); do
    if getent passwd $u &>/dev/null; then
        usermod -aG docker $u
    fi
done

chown root:root /etc/bash_completion.d/docker
chmod 644 /etc/bash_completion.d/docker

# Disable IPv6 in Docker.
sed -i -e \
    's/.*DOCKER_OPTS="\(.*\)"/DOCKER_OPTS="\1 --ipv6=false"/g' \
    /etc/default/docker

if [[ ! -f ${DOCKER_FILES}/docker-compose ]]; then
    wget --no-check-certificate -O ${DOCKER_FILES}/docker-compose \
        https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose
fi

cp -f ${DOCKER_FILES}/docker-compose \
      /etc/bash_completion.d/docker-compose

chown root:root /etc/bash_completion.d/docker-compose
chmod 644 /etc/bash_completion.d/docker-compose

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

sed -i -e \
    "s/GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 ${KERNEL_OPTIONS}\"/g" \
    /etc/default/grub

if [[ -f /etc/default/ufw ]]; then
    sed -i -e \
        's/DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/g' \
        /etc/default/ufw
fi

grep 'docker' /proc/mounts | awk '{ print length, $2 }' | \
    sort -gr | cut -d' ' -f2- | xargs umount -l -f 2> /dev/null || true

for d in /srv/docker /var/lib/docker; do
  [[ -d $d ]] || mkdir -p $d

  rm -rf ${d}/*

  chown root:root $d
  chmod 755 $d
done

# A bind-mount for the Docker root directory.
cat <<'EOS' | sed -e 's/\s\+/\t/g' | tee -a /etc/fstab
/srv/docker /var/lib/docker none bind 0 0
EOS

rm -f ${DOCKER_FILES}/docker{.key,-compose}
