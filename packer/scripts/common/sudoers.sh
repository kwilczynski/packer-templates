#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

MAJOR_VERSION=$(lsb_release -r | cut -f 2 | cut -d . -f 1)

sed -i -e \
    's/^\(.*env_keep = \"\)/\1PATH /' \
    /etc/sudoers

sed -i -e \
    's/^Defaults.*requiretty/Defaults\t!requiretty/' \
    /etc/sudoers

if [[ -n $MAJOR_VERSION ]]; then
    if (( $MAJOR_VERSION > 12 )); then
        sed -i -e \
            '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' \
            /etc/sudoers

        sed -i -e \
            's/%sudo\s*ALL=(ALL:ALL) ALL/%sudo\tALL=NOPASSWD:ALL/g' \
            /etc/sudoers
    else
        sed -i -e \
            '/Defaults\s\+env_reset/a Defaults\texempt_group=admin' \
            /etc/sudoers

        sed -i -e \
            's/%admin\s*ALL=(ALL) ALL/%admin\tALL=NOPASSWD:ALL/g' \
            /etc/sudoers
    fi
fi

if ! grep -q 'env_keep' /etc/sudoers &>/dev/null; then
    sed -i -e \
        '/Defaults\s\+env_reset/a Defaults\tenv_keep = "PATH SSH_AGENT_PID SSH_AUTH_SOCK"' \
        /etc/sudoers
fi

if ! grep -q 'requiretty' /etc/sudoers &>/dev/null; then
    sed -i -e \
        '/Defaults\s\+env_reset/i Defaults\t!requiretty,!tty_tickets' \
        /etc/sudoers
fi

chown root:root /etc/sudoers
chmod 0440 /etc/sudoers

for u in root ubuntu; do
    if getent passwd $u &>/dev/null; then
        echo "${u}:$(date | md5sum)" | chpasswd
        passwd -l $u
    fi
done

cat <<'EOF' | tee /etc/securetty
console
vc/1
tty1
EOF

chown root:root /etc/securetty
chmod 0440 /etc/securetty
