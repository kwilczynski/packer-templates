#!/bin/bash

#
# sshd.sh
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

join() {
    eval "local values=(\${$1[@]})"
    echo -n $(IFS=',' ; echo "${values[*]}")
}

# This is only applicable when building Amazon EC2 image (AMI).
AMAZON_EC2='no'
if wget -q --timeout 1 --wait 1 ---tries 2 --spider http://169.254.169.254/ &>/dev/null; then
    AMAZON_EC2='yes'
fi

SSH_SETTINGS=(
    'UseDNS no'
    'PermitRootLogin no'
    'GSSAPIAuthentication no'
    'ServerKeyBits 2048'
)

# The key exchange (KEX) algorithms.
KEX_ALGORITHMS=(
    curve25519-sha256@libssh.org
    diffie-hellman-group-exchange-sha256
)

SSH_SETTINGS+=( "KexAlgorithms $(join KEX_ALGORITHMS)" )

# The ciphers and algorithms used for session encryption.
CIPHERS=(
    chacha20-poly1305@openssh.com
    aes256-gcm@openssh.com
    aes128-gcm@openssh.com
    aes256-ctr
    aes192-ctr
    aes128-ctr
)

SSH_SETTINGS+=( "Ciphers $(join CIPHERS)" )

# The MAC (Message Authentication Code) algorithms.
MACS=(
    hmac-sha2-512-etm@openssh.com
    hmac-sha2-256-etm@openssh.com
    hmac-ripemd160-etm@openssh.com
    umac-128-etm@openssh.com
    hmac-sha2-512
    hmac-sha2-256
    hmac-ripemd160
    umac-128@openssh.com
)

SSH_SETTINGS+=( "MACs $(join MACS)" )

if [[ $AMAZON_EC2 == 'yes' ]]; then
    SSH_SETTINGS+=(
        'UseLogin no'
        'TCPKeepAlive no'
        'X11Forwarding no'
        'UsePrivilegeSeparation sandbox'
        'SyslogFacility AUTH'
        'LogLevel VERBOSE'
    )
fi

rm -f /etc/ssh/ssh_host_*
ssh-keygen -A

# Make the RSA key 4096 bits.
yes | ssh-keygen -t rsa -b 4096 -N '' \
    -f /etc/ssh/ssh_host_rsa_key || true

# Generate new moduli file to remove weak Diffie-Hellman Parameter
# set and to prevent the Logjam attack, see: https://weakdh.org/.
if wget --timeout 1 --wait 1 --tries 2 --spider https://2ton.com.au/ &>/dev/null; then
    # Remove old file.
    rm -f /etc/ssh/moduli

    # Fetch the Diffie-Hellman Parameter set from the company
    # that offers continuusly fresh copy as a public service.
    for bits in 2048 3072 4096 8192; do
        wget -q --no-check-certificate -O - https://2ton.com.au/dhparam/${bits}/ssh | \
            grep -vE '^#' | tee -a /etc/ssh/moduli >/dev/null
    done
else
    # Remove unsafe bit sizes.
    awk '$5 >= 2000' /etc/ssh/moduli > /etc/ssh/moduli.strong

    mv -f \
        /etc/ssh/moduli.strong \
        /etc/ssh/moduli
fi

for value in "${SSH_SETTINGS[@]}"; do
    SETTING=( $value )

    sed -i -e \
        "s/^#\?${SETTING[0]}.*/${value}/" \
        /etc/ssh/sshd_config

    grep -qF "$value" /etc/ssh/sshd_config || echo "$value" | \
        tee -a /etc/ssh/sshd_config >/dev/null
done
