#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

export DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical
export DEBCONF_NONINTERACTIVE_SEEN=true

readonly UBUNTU_VERSION=$(lsb_release -r | awk '{ print $2 }')

apt-get -y --force-yes --no-install-recommends install python-twisted-core python-configobj
apt-get -y --force-yes --no-install-recommends install landscape-common

rm -f /etc/update-motd.d/10-help-text \
      /etc/update-motd.d/51-cloudguest \
      /etc/update-motd.d/90-updates-available \
      /etc/update-motd.d/91-release-upgrade \
      /etc/update-motd.d/95-hwe-eol \
      /etc/update-motd.d/98-fsck-at-reboot \
      /etc/update-motd.d/98-reboot-required

mkdir -p /etc/landscape
chown root:root /etc/landscape
chmod 755 /etc/landscape

cat <<'EOF' | tee /etc/landscape/client.conf
[sysinfo]
exclude_sysinfo_plugins = Temperature,LandscapeLink
EOF

chown root:root /etc/landscape/client.conf
chmod 644 /etc/landscape/client.conf

if [[ -f /etc/init.d/landscape-client ]]; then
    service landscape-client stop &>/dev/null || true
    update-rc.d landscape-client disable
fi

cat <<'EOF' | tee /etc/update-motd.d/99-footer
#!/bin/sh

# Add extra information when showing message of the day.

[ -f /etc/motd.tail ] && cat /etc/motd.tail 2>/dev/null || true

printf "\n"
exit 0
EOF

chown root:root /etc/update-motd.d/99-footer
chmod 755 /etc/update-motd.d/99-footer

rm -f /etc/motd

rm -f /etc/motd.tail
touch /etc/motd.tail

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    if ! egrep -q 'motd=.+motd(\.dynamic)?' /etc/pam.d/sshd &>/dev/null; then
        sed -i -e \
            's#\(^session.*pam_motd.so\)\+#\1 motd=/run/motd noupdate\n&#' \
                /etc/pam.d/sshd
    fi

    if ! egrep -q 'motd=.+motd(\.dynamic)?' /etc/pam.d/login &>/dev/null; then
        sed -i -e \
            's#\(^session.*pam_motd.so\)\+#\1 motd=/run/motd noupdate\n&#' \
                /etc/pam.d/login
    fi

    ( run-parts --lsbsysinit /etc/update-motd.d ) | tee /run/motd

    chown root:root /run/motd
    chmod 644 /run/motd
else
    ( run-parts --lsbsysinit /etc/update-motd.d ) | tee /var/run/motd.dynamic

    chown root:root /var/run/motd.dynamic
    chmod 644 /var/run/motd.dynamic
fi
