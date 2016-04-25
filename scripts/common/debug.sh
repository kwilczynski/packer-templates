#!/bin/bash

#
# debug.sh
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

# Get details about the Ubuntu release ...
readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

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

FILES=( syslog messages )
for file in ${FILES[@]}; do
  if [[ -f /var/log/${file} ]]; then
    tail -100 /var/log/${file}
  fi
done

if [[ $UBUNTU_VERSION == '16.04' ]]; then
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
