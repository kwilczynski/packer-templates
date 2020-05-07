#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly PROXMOX=$(detect_proxmox && echo 'true')

sed -i -e \
    's/^\(.*env_keep = \"\)/\1PATH /' \
    /etc/sudoers

sed -i -e \
    's/^Defaults.*requiretty/Defaults\t!requiretty/' \
    /etc/sudoers

sed -i -e \
    "/Defaults\s\+env_reset/a Defaults\texempt_group=sudo" \
    /etc/sudoers

sed -i -e \
    "s/%sudo\s*ALL=(ALL:ALL) ALL/%sudo\tALL=NOPASSWD:ALL/g" \
    /etc/sudoers

if ! grep -q 'env_keep' /etc/sudoers; then
    sed -i -e \
        '/Defaults\s\+env_reset/a Defaults\tenv_keep = "PATH HOME SSH_AGENT_PID SSH_AUTH_SOCK"' \
        /etc/sudoers
fi

if ! grep -q 'requiretty' /etc/sudoers; then
    sed -i -e \
        '/Defaults\s\+env_reset/i Defaults\t!requiretty,!tty_tickets' \
        /etc/sudoers
fi

chown root: /etc/sudoers
chmod 440 /etc/sudoers

chown root: /etc/sudoers.d
chmod 750 /etc/sudoers.d

USERS=('root')
if [[ -z $PROXMOX ]]; then
    USERS+=('ubuntu')
fi

for user in "${USERS[@]}"; do
    if getent passwd "$user" &>/dev/null; then
        echo "${user}:$(date | md5sum)" | chpasswd
        passwd -l "$user"
    fi
done

cat <<'EOF' > /etc/securetty
console
tty1
vc/1
EOF

chown root: /etc/securetty
chmod 440 /etc/securetty

# Make sure to disallow access to "su" for everyone
# other than a root user or a decidated group.
dpkg-statoverride --update --add root sudo 4750 /bin/su
