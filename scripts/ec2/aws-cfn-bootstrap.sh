#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly EC2_FILES='/var/tmp/ec2'

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

[[ -d $EC2_FILES ]] || mkdir -p "$EC2_FILES"

AWS_CFN_BOOTSTRAP='aws-cfn-bootstrap-1.4-8.tar.gz'
if [[ -n $AWS_CFN_BOOTSTRAP_VERSION ]]; then
    AWS_CFN_BOOTSTRAP="aws-cfn-bootstrap-${AWS_CFN_BOOTSTRAP_VERSION}.tar.gz"
fi

if [[ ! -f "${EC2_FILES}/${AWS_CFN_BOOTSTRAP}" ]]; then
    wget -O "${EC2_FILES}/${AWS_CFN_BOOTSTRAP}" \
        "https://s3.amazonaws.com/cloudformation-examples/${AWS_CFN_BOOTSTRAP}"
fi

mkdir -p /tmp/aws-cfn-bootstrap

tar -zxf "${EC2_FILES}/${AWS_CFN_BOOTSTRAP}" --strip=1 -C \
    /tmp/aws-cfn-bootstrap

# We can install the aws-cfn-bootstrap, but it has to be done
# under virtualenv as it has specific version requirements on
# its dependencies, often causing other things to break.
virtualenv /opt/aws-cfn-bootstrap
pushd /opt/aws-cfn-bootstrap &>/dev/null

# Make sure to switch into the virtualenv.
source /opt/aws-cfn-bootstrap/bin/activate

# This is needed, as virtualenv by default will install
# some really old version (e.g. 12.0.x, etc.), sadly.
pip install --upgrade setuptools

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

# Dependency needed by the cfn-hup.
pip install python-daemon

pushd /tmp/aws-cfn-bootstrap &>/dev/null

python setup.py clean -a
python setup.py build \
    --executable="$(which python)"

# Correct the hardcoded path to Python executable.
find ./build -type f -name 'cfn-*' -print0 | xargs -0 \
    sed -i -e "s/^#\!.*/#\!$(which python | sed -e 's/\//\\\//g')/"

# The "--install-scripts" option is to make sure that binary
# will be placed in the system-wide directory, rather than
# inside the virtualenv environment only.
python setup.py install -O2 \
    --install-scripts='/usr/local/bin'

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    # The cfn-hup script does not really support systemd.
    cat <<'EOF' > /lib/systemd/system/cfn-hup.service
    [Unit]
    Description=CloudFormation cfn-hup

    [Service]
    Type=simple
    ExecStart=/usr/local/bin/cfn-hup --no-daemon
    Restart=always

    [Install]
    WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    # This service would exit without a valid configuration,
    # which is why we leave it stopped, and it has to be
    # enabled and/or started using instance user-data, or a
    # bootstrap script, etc.
    for option in disable stop; do
        systemctl "$option" cfn-hup
    done
else
    cp "${PWD}/init/ubuntu/cfn-hup" \
        /etc/init.d/cfn-hup

    chown root: /etc/init.d/cfn-hup
    chmod 755 /etc/init.d/cfn-hup

    for option in defaults stop disable; do
        update-rc.d cfn-hup "$option" || true
    done
fi

popd &>/dev/null

deactivate
popd &>/dev/null

for file in /usr/local/bin/cfn-*; do
    ln -sf "$file" "/usr/bin/${file##*/}"
done

hash -r

for directory in /etc/cfn /etc/cfn/hooks.d; do
    mkdir -p "$directory"
    chown root: "$directory"
    chmod 755 "$directory"
done

rm -Rf "${EC2_FILES}/${AWS_CFN_BOOTSTRAP:?}" \
       /tmp/aws-cfn-bootstrap
