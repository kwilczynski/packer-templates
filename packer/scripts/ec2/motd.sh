#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

if [[ -n $PACKER_BUILD_TIMESTAMP ]]; then
    BUILD_TIMESTAMP=$PACKER_BUILD_TIMESTAMP
else
    BUILD_TIMESTAMP=$(TZ=UTC date +%s)
fi

readonly BUILD_DATE="$(date -d @${BUILD_TIMESTAMP})"

cat <<EOF | tee /etc/os-release-ec2
BUILD_NAME="${PACKER_BUILD_NAME:-"UNKNOWN"}"
BUILD_NUMBER=${BUILD_NUMBER:-0}
BUILD_TIMESTAMP=$BUILD_TIMESTAMP
BUILD_DATE="${BUILD_DATE}"
BUILDER_TYPE="${PACKER_BUILDER_TYPE:-"UNKNOWN"}"
BUILDER_SOURCE_AMI="${PACKER_SOURCE_AMI:-"UNKNOWN"}"
VERSION="${PACKER_BUILD_VERSION:-"DEVELOPMENT"}"
EOF

chown root:root /etc/os-release-ec2
chmod 644 /etc/os-release-ec2
