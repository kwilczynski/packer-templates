#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly UBUNTU_VERSION=$(detect_ubuntu_version)

readonly HOSTNAME="ubuntu$(detect_ubuntu_version | tr -d '.')"
readonly FQDN="${HOSTNAME}.localdomain"

(
    cat <<EOF
postfix postfix/bad_recipient_delimiter note
postfix postfix/chattr boolean false
postfix postfix/db_upgrade_warning boolean true
postfix postfix/default_transport string error
postfix postfix/relay_transport string error
postfix postfix/destinations string $HOSTNAME, $FQDN, localhost.localdomain, localhost
postfix postfix/dynamicmaps_upgrade_warning boolean
postfix postfix/inet_interfaces string loopback-only
postfix postfix/kernel_version_warning boolean
postfix postfix/mailbox_limit string 0
postfix postfix/mailbox_size_limit string 0
postfix postfix/mailname string /etc/mailname
postfix postfix/mailname seen true
postfix postfix/main_mailer_type select Local only
postfix postfix/master_upgrade_warning boolean
postfix postfix/mydomain_warning boolean
postfix postfix/myhostname string localhost
postfix postfix/mynetworks string 127.0.0.0/8 10.0.2.0/24
postfix postfix/not_configured note
postfix postfix/nqmgr_upgrade_warning boolean
postfix postfix/procmail boolean false
postfix postfix/protocols select ipv4
postfix postfix/recipient_delimiter string +
postfix postfix/relayhost string
postfix postfix/retry_upgrade_warning boolean
postfix postfix/rfc1035_violation boolean false
postfix postfix/root_address string
postfix postfix/tlsmgr_upgrade_warning boolean
postfix postfix/transport_map_warning note
postfix postfix/smtpd_use_tls boolean false
EOF
) | debconf-set-selections

cat <<'EOF' > /etc/aliases
root:       vagrant

postmaster: root

bin:        root
daemon:     root
named:      root
uucp:       root
www:        root
ftp-bugs:   root
postfix:    root

manager:    root
operator:   root
dumper:     root
decode:     root

abuse:      postmaster
spam:       postmaster

nobody:         /dev/null
do-not-reply:   /dev/null

MAILER-DAEMON:  postmaster
EOF

chown root: /etc/aliases
chmod 644 /etc/aliases

echo "$FQDN" > /etc/mailname

chown root: /etc/mailname
chmod 644 /etc/mailname

apt_get_update

apt-get --assume-yes install postfix

if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    systemctl stop postfix
else
    service postfix stop
fi

dpkg-reconfigure postfix

sed -i -e \
    's/.*inet_protocols.+/inet_protocols = ipv4/g' \
    /etc/postfix/main.cf

if ! grep -q 'inet_protocols' /etc/postfix/main.cf; then
    cat <<'EOF' >> /etc/postfix/main.cf
inet_protocols = ipv4
EOF
fi

sed -i -e \
    's/^.*biff.*/biff = no/' \
    /etc/postfix/main.cf

sed -i -e \
    $'s/^.*smtpd_banner.*/smtpd_banner = $myhostname ESMTP/' \
    /etc/postfix/main.cf

newaliases

for action in restart stop; do
    if [[ ! $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
        systemctl "$action" postfix
    else
        service postfix "$action"
  fi
done
