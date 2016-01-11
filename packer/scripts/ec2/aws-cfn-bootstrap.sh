#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly EC2_FILES='/var/tmp/ec2'

[[ -d $EC2_FILES ]] || mkdir -p $EC2_FILES

CFN_HELPERS='aws-cfn-bootstrap-1.4-8.tar.gz'
if [[ ! -f ${EC2_FILES}/${CFN_HELPERS} ]]; then
    wget --no-check-certificate -O ${EC2_FILES}/${CFN_HELPERS} \
        https://s3.amazonaws.com/cloudformation-examples/${CFN_HELPERS}
fi

mkdir -p /tmp/aws-cfn-bootstrap

tar -zxf ${EC2_FILES}/${CFN_HELPERS} --strip-components=1 -C \
    /tmp/aws-cfn-bootstrap

pushd /tmp/aws-cfn-bootstrap &>/dev/null

python setup.py clean -a

python setup.py install -O2 \
    --install-scripts=/usr/local/bin

popd &>/dev/null

for file in /usr/local/bin/cfn-*; do
    ln -sf $file /usr/bin/${file##*/}
done

hash -r

rm -rf ${EC2_FILES}/${CFN_HELPERS} \
       /tmp/ec2-ami-tools-archive
