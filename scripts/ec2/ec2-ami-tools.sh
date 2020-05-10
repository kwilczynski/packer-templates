#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly EC2_FILES='/var/tmp/ec2'

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

[[ -d $EC2_FILES ]] || mkdir -p $EC2_FILES

EC2_AMI_TOOLS='ec2-ami-tools-1.5.7.zip'
if [[ -n $EC2_AMI_TOOLS_VERSION ]]; then
    EC2_AMI_TOOLS="ec2-ami-${EC2_AMI_TOOLS_VERSION}.zip"
fi

if [[ ! -f "${EC2_FILES}/${EC2_AMI_TOOLS}" ]]; then
    wget -O "${EC2_FILES}/${EC2_AMI_TOOLS}" \
        "http://s3.amazonaws.com/ec2-downloads/${EC2_AMI_TOOLS}"
fi

# Dependencies needed by the Amazon EC2 AMI Tools.
PACKAGES=(
    'grub'
    'parted'
    'kpartx'
    'unzip'
    'rsync'
    'ruby2.3'
)

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    PACKAGES+=( 'ruby2.3' )
else
    PACKAGES+=( 'ruby1.9.3' )
fi

apt_get_update

for package in "${PACKAGES[@]}"; do
    apt-get --assume-yes install "$package"
done

if [[ -x /usr/bin/ruby2.3 ]]; then
    # Make sure that Ruby is available as "ruby", given the PATH set corretly.
    update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby2.3 50
fi

hash -r

mkdir -p /tmp/ec2-ami-tools-archive \
         /var/tmp/ec2-ami-tools/{bin,etc,lib}

unzip "${EC2_FILES}/${EC2_AMI_TOOLS}" -d \
      /tmp/ec2-ami-tools-archive

for directory in bin etc lib; do
    cp -rf /tmp/ec2-ami-tools-archive/ec2-ami-tools*/${directory:?}/* \
           "/var/tmp/ec2-ami-tools/${directory:?}"
done

chown -R root: /var/tmp/ec2-ami-tools
chmod 755 /var/tmp/ec2-ami-tools/bin/*

find /var/tmp/ec2-ami-tools/{etc,lib} -type f -print0 | \
    xargs -0 chmod -f 644

rm -Rf /tmp/ec2-ami-tools-archive
