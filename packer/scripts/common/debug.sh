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

FILES=( syslog messages )
for file in ${FILES[@]}; do
  if [[ -f /var/log/${file} ]]; then
    tail -100 /var/log/${file}
  fi
done

printf "\n"

if [[ -f /var/log/secure ]]; then
  tail -100 /var/log/secure
fi

sleep 60
