#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

uname -a
printf "\n"

free -tk
printf "\n"

env
printf "\n"

locale
printf "\n"

locale -a
printf "\n"

ps -ef
printf "\n"

lsof -nP
printf "\n"

dmesg
printf "\n"

find /tmp /var/tmp
printf "\n"

FILES=(
    'syslog'
    'messages'
    'auth.log'
    'kern.log'
)

for file in "${FILES[@]}"; do
    if [[ -f "/var/log/${file}" ]]; then
        tail -100 "/var/log/${file}"
    fi
done

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    printf "\n"
    {
      systemctl status
      journalctl -xe
    } | tee
fi

printf "\n"
if [[ -f /var/log/secure ]]; then
    tail -100 /var/log/secure
fi

sleep 60
