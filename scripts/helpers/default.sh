#!/usr/bin/bash

join() {
    local IFS="$1"; shift
    echo "$*"
}

apt_get_update() {
    # Refresh packages index only when needed.
    local update_stamp='/var/lib/apt/periodic/update-success-stamp'
    if [[ ! -f $update_stamp ]] || \
       (( $(date +%s) - $(date -r $update_stamp +%s) > 900 )); then
        apt-get --assume-yes update 1>/dev/null
    fi
}

detect_platform() {
    case "$(uname -m)" in
        x86|i?86)
            echo i386;
        ;;
        x86_64|amd64)
            echo amd64;
        ;;
    esac
}

detect_os() {
    local os

    os="$(uname | tr '[:upper:]' '[:lower:]')"

    case "$os" in
        linux|linux-gnu)
            echo 'linux'
        ;;
        *)
            echo "$os"
        ;;
    esac
}

detect_grub2() {
    local status=0
    set +e
    [[ $(grub-install --version 2>/dev/null) =~ (1.9|2.0) ]]
    status=$?
    set -e
    return $status
}

detect_amazon_ec2() {
    local status=0
    set +e
    wget --no-proxy --tries 1 --connect-timeout=2 \
         'http://169.254.169.254/' &>/dev/null
    status=$?
    set -e
    return $status
}

detect_vmware() {
    local status=0
    set +e
    [[ $PACKER_BUILDER_TYPE =~ ^vmware.*$ ]]
    status=$?
    set -e
    return $status
}

detect_proxmox() {
    local status=0
    set +e
    [[ $PACKER_BUILDER_TYPE =~ ^proxmox$ ]]
    status=$?
    set -e
    return $status
}

detect_ubuntu_release() {
    lsb_release -sc
}

detect_ubuntu_version() {
    lsb_release -r | awk '{ print $2 }'
}

clean_apt_policy() {
    rm -f /usr/sbin/policy-rc.d
}

umask 022

export LC_ALL=C LANGUAGE=C LANG=C

export DEBIAN_FRONTEND='noninteractive'
export DEBCONF_NONINTERACTIVE_SEEN='true'
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE='true'

trap clean_apt_policy EXIT

cat <<'EOF' > /usr/sbin/policy-rc.d
#!/bin/sh
exit 101
EOF

