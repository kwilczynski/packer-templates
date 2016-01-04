#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly EC2_FILES='/var/tmp/ec2'

# Dependencies needed by the Amazon EC2 AMI Tools.
PACKAGES=( grub parted kpartx unzip rsync ruby1.9.3 )
for package in "${PACKAGES[@]}"; do
    apt-get -y --force-yes install $package
    apt-mark manual $package
done

hash -r

EC2_AMI_TOOLS='ec2-ami-tools.zip'
if [[ -n $EC2_AMI_TOOLS_VERSION ]]; then
    EC2_AMI_TOOLS="ec2-ami-${EC2_AMI_TOOLS_VERSION}.zip"
fi

[[ -d $EC2_FILES ]] || mkdir -p $EC2_FILES

if [[ ! -f ${EC2_FILES}/${EC2_AMI_TOOLS} ]]; then
    wget --no-check-certificate -O ${EC2_FILES}/${EC2_AMI_TOOLS} \
        http://s3.amazonaws.com/ec2-downloads/${EC2_AMI_TOOLS}
fi

mkdir -p /tmp/ec2-ami-tools-archive \
         /var/tmp/ec2-ami-tools/{bin,etc,lib}

unzip ${EC2_FILES}/${EC2_AMI_TOOLS} -d \
      /tmp/ec2-ami-tools-archive

for d in bin etc lib; do
    cp -rf /tmp/ec2-ami-tools-archive/ec2-ami-tools*/${d}/* \
           /var/tmp/ec2-ami-tools/${d}
done

chown -R root:root /var/tmp/ec2-ami-tools
chmod 755 /var/tmp/ec2-ami-tools/bin/*

find /var/tmp/ec2-ami-tools/{etc,lib} -type f | xargs chmod -f 644

rm -rf /tmp/ec2-ami-tools-archive
