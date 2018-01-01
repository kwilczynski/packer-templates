#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

cat <<'EOF' > /etc/modprobe.d/blacklist-ipv6.conf
options ipv6 disable=1
alias net-pf-10 off
alias ipv6 off
install ipv6 /bin/true
blacklist ipv6
EOF

cat <<'EOF' > /etc/sysctl.d/10-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

chown root: /etc/modprobe.d/blacklist-ipv6.conf \
            /etc/sysctl.d/10-disable-ipv6.conf

chmod 644 /etc/modprobe.d/blacklist-ipv6.conf \
          /etc/sysctl.d/10-disable-ipv6.conf

if [[ -f /etc/netconfig ]]; then
    sed -i -e \
        '/^\(udp\|tcp\)6/ d' \
        /etc/netconfig
fi

# Configure getaddrinfo() family to prefer IPv4 over IPv6 by default
# to ensure that DNS resolution does not get stuck when AAAA records
# are being returned (which is the default preference these days).
cat <<'EOF' > /etc/gai.conf
reload no

label ::1/128       0
label ::/0          1
label 2002::/16     2
label ::/96         3
label ::ffff:0:0/96 4
label fec0::/10     5
label fc00::/7      6
label 2001:0::/32   7

precedence  ::1/128       50
precedence  ::/0          40
precedence  2002::/16     30
precedence ::/96          20
precedence ::ffff:0:0/96  100

scopev4 ::ffff:169.254.0.0/112  2
scopev4 ::ffff:127.0.0.0/104    2
scopev4 ::ffff:0.0.0.0/96       14
EOF

chown root: /etc/gai.conf
chmod 644 /etc/gai.conf

# Support both grub and grub2 style configuration.
if detect_grub2; then
    sed -i -e \
        's/.*GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/g' \
        /etc/default/grub
else
    sed -i -e \
        's/^#\sdefoptions=\(.*\)/# defoptions=\1 ipv6.disable=1/' \
        /boot/grub/menu.lst
fi
