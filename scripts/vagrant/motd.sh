#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly PACKER_BUILDER_TYPE=${PACKER_BUILDER_TYPE//-*}

if [[ -n $PACKER_BUILD_TIMESTAMP ]]; then
    BUILD_TIMESTAMP="$PACKER_BUILD_TIMESTAMP"
else
    BUILD_TIMESTAMP=$(TZ=UTC date +%s)
fi

readonly BUILD_DATE=$(date -d "@${BUILD_TIMESTAMP}")

cat <<EOF > /etc/os-release-vagrant
BUILD_NAME="${PACKER_BUILD_NAME:-"UNKNOWN"}"
BUILD_NUMBER=${BUILD_NUMBER:-0}
BUILD_TIMESTAMP=$BUILD_TIMESTAMP
BUILD_DATE="${BUILD_DATE}"
BUILDER_TYPE="${PACKER_BUILDER_TYPE:-"UNKNOWN"}"
VERSION="${PACKER_BUILD_VERSION:-"DEVELOPMENT"}"
EOF

chown root: /etc/os-release-vagrant
chmod 644 /etc/os-release-vagrant

cat <<'EOF' > /etc/update-motd.d/10-vagrant
#!/bin/sh

[ -f /etc/os-release-vagrant ] || exit 0

# Add information about this particular Vagrant box e.g., version, etc.
. /etc/os-release-vagrant

# Calculate the level of indentation.
_indent() { echo "(${#1} + 75) / 2" | bc; }

readonly HEADER="$BUILD_NAME (${BUILDER_TYPE})"
readonly VERSION="Box version: ${VERSION}"

printf "\n%*s\n" "$(_indent "$HEADER")" "$HEADER"
cat <<'EOS'
                 _____ _____ _____ _____ _____ _____ _____
                |  |  |  _  |   __| __  |  _  |   | |_   _|
                |  |  |     |  |  |    -|     | | | | | |
                 \___/|__|__|_____|__|__|__|__|_|___| |_|
EOS
printf "%*s\n%*s\n" \
  "$(_indent "$BUILD_DATE")" "$BUILD_DATE" \
  "$(_indent "${VERSION}")" "$VERSION"

exit 0
EOF

chown root: /etc/update-motd.d/10-vagrant
chmod 755 /etc/update-motd.d/10-vagrant
