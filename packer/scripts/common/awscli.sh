#!/bin/bash

#
# awscli.sh
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

# Set default desirable region.
if [[ -z $AWS_DEFAULT_REGION ]]; then
    AWS_DEFAULT_REGION='us-east-1'
fi

cat <<'EOF' > /etc/bash_completion.d/aws
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
        cat <<EOF | sed -e '/^$/d' > ${HOME_DIRECTORY}/.aws/config
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
