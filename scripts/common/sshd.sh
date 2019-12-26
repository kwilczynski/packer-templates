#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly AMAZON_EC2=$(detect_amazon_ec2 && echo 'true')

SSH_SETTINGS=(
    'UseDNS no'
    'Compression no'
    'PermitRootLogin no'
    'GSSAPIAuthentication no'
    'UsePrivilegeSeparation sandbox'
    'ServerKeyBits 2048'
)

# The key exchange (KEX) algorithms.
KEX_ALGORITHMS=(
    'curve25519-sha256@libssh.org'
    'diffie-hellman-group-exchange-sha256'
)

SSH_SETTINGS+=( "KexAlgorithms $(join $',' "${KEX_ALGORITHMS[@]}")" )

# The ciphers and algorithms used for session encryption.
CIPHERS=(
    'chacha20-poly1305@openssh.com'
    'aes256-gcm@openssh.com'
    'aes128-gcm@openssh.com'
    'aes256-ctr'
    'aes192-ctr'
    'aes128-ctr'
)

SSH_SETTINGS+=( "Ciphers $(join $',' "${CIPHERS[@]}")" )

# The MAC (Message Authentication Code) algorithms.
MACS=(
    'hmac-sha2-512-etm@openssh.com'
    'hmac-sha2-256-etm@openssh.com'
    'hmac-ripemd160-etm@openssh.com'
    'umac-128-etm@openssh.com'
    'hmac-sha2-512'
    'hmac-sha2-256'
    'hmac-ripemd160'
    'umac-128@openssh.com'
)

SSH_SETTINGS+=( "MACs $(join $',' "${MACS[@]}")" )

if [[ -n $AMAZON_EC2 ]]; then
    SSH_SETTINGS+=(
        'UseLogin no'
        'TCPKeepAlive no'
        'X11Forwarding no'
        'AllowTcpForwarding no'
        'AllowAgentForwarding no'
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
if wget --no-proxy --tries 1 --connect-timeout=2 https://2ton.com.au/ &>/dev/null; then
    # Remove old file.
    rm -f /etc/ssh/moduli

    # Fetch the Diffie-Hellman Parameter set from the company
    # that offers continuusly fresh copy as a public service.
    for bits in 2048 3072 4096 8192; do
        wget -q -O - "https://2ton.com.au/dhparam/${bits}/ssh" | \
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
