#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly EC2_FILES='/var/tmp/ec2'

[[ -d $EC2_FILES ]] || mkdir -p $EC2_FILES

AWS_CFN_BOOTSTRAP='aws-cfn-bootstrap-1.4-8.tar.gz'
if [[ -n $AWS_CFN_BOOTSTRAP_VERSION ]]; then
    AWS_CFN_BOOTSTRAP="aws-cfn-bootstrap-${AWS_CFN_BOOTSTRAP_VERSION}.tar.gz"
fi

if [[ ! -f ${EC2_FILES}/${AWS_CFN_BOOTSTRAP} ]]; then
    wget --no-check-certificate -O ${EC2_FILES}/${AWS_CFN_BOOTSTRAP} \
        https://s3.amazonaws.com/cloudformation-examples/${AWS_CFN_BOOTSTRAP}
fi

mkdir -p /tmp/aws-cfn-bootstrap

tar -zxf ${EC2_FILES}/${AWS_CFN_BOOTSTRAP} --strip=1 -C \
    /tmp/aws-cfn-bootstrap

# Dependency needed by the cfn-hup.
pip install python-daemon

pushd /tmp/aws-cfn-bootstrap &>/dev/null

python setup.py clean -a
python setup.py install -O2 \
    --install-scripts=/usr/local/bin

cp ${PWD}/init/ubuntu/cfn-hup \
   /etc/init.d/cfn-hup

chown root: /etc/init.d/cfn-hup
chmod 755 /etc/init.d/cfn-hup

popd &>/dev/null

for file in /usr/local/bin/cfn-*; do
    ln -sf $file /usr/bin/${file##*/}
done

hash -r

for option in defaults disable; do
    update-rc.d cfn-hup $option || true
done

for directory in /etc/cfn /etc/cfn/hooks.d; do
    mkdir -p $directory
    chown root: $directory
    chmod 755 $directory
done

cat <<'EOF' | tee /etc/cfn/cfn-hup.conf
[main]
stack=
region=
interval=10
verbose=false
EOF

chown root: /etc/cfn/cfn-hup.conf
chmod 644 /etc/cfn/cfn-hup.conf

cat <<'EOF' | tee /etc/cfn/hooks.d/cfn-auto-reloader.conf
[cfn-auto-reloader-hook]
triggers=post.update
path=
action=
EOF

chown root: /etc/cfn/hooks.d/cfn-auto-reloader.conf
chmod 644 /etc/cfn/hooks.d/cfn-auto-reloader.conf

rm -rf ${EC2_FILES}/${AWS_CFN_BOOTSTRAP} \
       /tmp/ec2-ami-tools-archive
