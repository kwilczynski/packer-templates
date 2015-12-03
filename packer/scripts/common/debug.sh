#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

uname -a
printf "\n"

free -tk
printf "\n"

env
printf "\n"

locale
printf "\n"

ps -ef
printf "\n"

lsof -nP
printf "\n"

dmesg
printf "\n"

find /tmp /var/tmp
printf "\n"

if [[ -f /var/log/syslog ]]; then
    tail -100 /var/log/syslog
fi

sleep 60
