#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

# A list of Ruby gems to install alongside Itamae.
GEMS=(
    'specinfra-ec2_metadata-tags'
)

# By default, assume that latest version of Itamae is stable.
if [[ -n $ITAMAE_VERSION ]]; then
    gem install --no-document --no-suggestions itamae --version "$ITAMAE_VERSION"
else
    gem install --no-document --no-suggestions itamae
fi

for gem in "${GEMS[@]}"; do
    gem install --no-document --no-suggestions "$gem"
done
