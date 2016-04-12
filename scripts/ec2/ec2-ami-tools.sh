#!/bin/bash

#
# ec2-ami-tools.sh
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

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly EC2_FILES='/var/tmp/ec2'

[[ -d $EC2_FILES ]] || mkdir -p $EC2_FILES

EC2_AMI_TOOLS='ec2-ami-tools-1.5.7.zip'
if [[ -n $EC2_AMI_TOOLS_VERSION ]]; then
    EC2_AMI_TOOLS="ec2-ami-${EC2_AMI_TOOLS_VERSION}.zip"
fi

if [[ ! -f ${EC2_FILES}/${EC2_AMI_TOOLS} ]]; then
    wget --no-check-certificate -O ${EC2_FILES}/${EC2_AMI_TOOLS} \
        http://s3.amazonaws.com/ec2-downloads/${EC2_AMI_TOOLS}
fi

# Dependencies needed by the Amazon EC2 AMI Tools.
PACKAGES=( grub parted kpartx unzip rsync ruby1.9.3 )

for package in "${PACKAGES[@]}"; do
    apt-get -y --force-yes install $package
done

hash -r

mkdir -p /tmp/ec2-ami-tools-archive \
         /var/tmp/ec2-ami-tools/{bin,etc,lib}

unzip ${EC2_FILES}/${EC2_AMI_TOOLS} -d \
      /tmp/ec2-ami-tools-archive

for directory in bin etc lib; do
    cp -rf /tmp/ec2-ami-tools-archive/ec2-ami-tools*/${directory}/* \
           /var/tmp/ec2-ami-tools/${directory}
done

chown -R root: /var/tmp/ec2-ami-tools
chmod 755 /var/tmp/ec2-ami-tools/bin/*

find /var/tmp/ec2-ami-tools/{etc,lib} -type f | \
    xargs chmod -f 644

rm -rf /tmp/ec2-ami-tools-archive
