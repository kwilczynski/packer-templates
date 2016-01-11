#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Set default desirable region.
if [[ -z $AWS_DEFAULT_REGION ]]; then
    AWS_DEFAULT_REGION='us-east-1'
fi

cat <<'EOF' | tee /etc/bash_completion.d/aws
complete -C aws_completer aws
EOF

chown root: /etc/bash_completion.d/aws
chmod 644 /etc/bash_completion.d/aws

# Resolve the "InsecurePlatformWarning" warning.
pip install --upgrade ndg-httpsclient

# The "--install-scripts" option is to make sure that binary
# will be placed in the system-wide directory, rather than
# inside the virtualenv environment only.
if [[ -n $AWSCLI_VERSION ]]; then
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        awscli==${AWSCLI_VERSION}
else
    pip install \
        --install-option='--install-scripts=/usr/local/bin' \
        awscli
fi

rm -f /usr/local/bin/aws.cmd \
      /usr/local/bin/aws_zsh_completer.sh

# Remove not really needed documentation.
rm -rf /usr/local/lib/python*/dist-packages/awscli/examples || true

for file in /usr/local/bin/aws*; do
    ln -sf $file /usr/bin/${file##*/}
done

hash -r

for user in $(echo "root vagrant ubuntu ${USER}" | tr ' ' '\n' | sort -u); do
    if getent passwd $user &>/dev/null; then
        # Not using the "HOME" environment variable here,
        # to avoid breaking things during the image build.
        eval HOME_DIRECTORY='~'${user}

        [[ -d ${HOME_DIRECTORY}/.aws ]] || mkdir -p ${HOME_DIRECTORY}/.aws

        # Basic, just to set correct region.
        cat <<EOF | sed -e '/^$/d' | tee ${HOME_DIRECTORY}/.aws/config
[default]
$(if [[ $PACKER_BUILDER_TYPE =~ ^amazon-.+$ ]]; then
    printf "%s = %s" "region" $AWS_DEFAULT_REGION
  fi)
output = json
EOF

        # Make sure permissions are set for the desired user.
        chown -R ${user}:$(id -gn $user 2>/dev/null) ${HOME_DIRECTORY}/.aws
        chmod 700 ${HOME_DIRECTORY}/.aws
        chmod 600 ${HOME_DIRECTORY}/.aws/config
    fi
done
