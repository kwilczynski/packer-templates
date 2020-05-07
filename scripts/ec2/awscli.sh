#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly AMAZON_EC2=$(detect_amazon_ec2 && echo 'true')

# Set default desirable region.
if [[ -z $AWS_DEFAULT_REGION ]]; then
    AWS_DEFAULT_REGION='us-east-1'
fi

cat <<'EOF' > /etc/bash_completion.d/aws
complete -C aws_completer aws
EOF

chown root: /etc/bash_completion.d/aws
chmod 644 /etc/bash_completion.d/aws

# We can install the awscli pip, but it has to be done under
# virtualenv as it has specific version requirements on its
# dependencies, often causing other things to break.
virtualenv /opt/awscli
pushd /opt/awscli &>/dev/null

# Make sure to switch into the virtualenv.
source /opt/awscli/bin/activate

# This is needed, as virtualenv by default will install
# some really old version (e.g. 12.0.x, etc.), sadly.
pip install --upgrade setuptools

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

# The "--install-scripts" option is to make sure that binary
# will be placed in the system-wide directory, rather than
# inside the virtualenv environment only.
if [[ -n $AWSCLI_VERSION ]]; then
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        awscli=="${AWSCLI_VERSION}"
else
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        awscli
fi

# Install the CloudWatch Logs plugin.
pip install awscli-cwlogs

deactivate
popd &>/dev/null

rm -f /usr/local/bin/aws.cmd \
      /usr/local/bin/aws_zsh_completer.sh

# Remove not really needed documentation.
rm -Rf /usr/local/lib/python*/dist-packages/awscli/examples || true

for file in /usr/local/bin/aws*; do
    ln -sf "$file" "/usr/bin/${file##*/}"
done

hash -r

for user in $(echo "root ubuntu ${USER}" | tr ' ' '\n' | sort -u); do
    if getent passwd "$user" &>/dev/null; then
        # Not using the "HOME" environment variable here,
        # to avoid breaking things during the image build.
        eval HOME_DIRECTORY="~${user}"

        [[ -d "${HOME_DIRECTORY}/.aws" ]] || mkdir -p "${HOME_DIRECTORY}/.aws"

        # Basic, just to set correct region.
        cat <<EOF | sed -e '/^$/d' > "${HOME_DIRECTORY}/.aws/config"
[plugins]
cwlogs = cwlogs

[default]
$(if [[ -n $AMAZON_EC2 ]]; then
    printf "%s = %s" "region" $AWS_DEFAULT_REGION
  fi)
output = json
EOF

        # Make sure permissions are set for the desired user.
        chown -R "${user}:$(id -gn "$user" 2>/dev/null)" "${HOME_DIRECTORY}/.aws"
        chmod 700 "${HOME_DIRECTORY}/.aws"
        chmod 600 "${HOME_DIRECTORY}/.aws/config"
    fi
done
