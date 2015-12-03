#!/bin/bash

set -e

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

cat <<'EOF' | tee /etc/modprobe.d/blacklist-ipv6.conf
alias net-pf-10 off
alias ipv6 off
install ipv6 /bin/true
blacklist ipv6
EOF

cat <<'EOF' | tee /etc/sysctl.d/10-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

chown root:root /etc/modprobe.d/blacklist-ipv6.conf \
                /etc/sysctl.d/10-disable-ipv6.conf

chmod 644 /etc/modprobe.d/blacklist-ipv6.conf \
          /etc/sysctl.d/10-disable-ipv6.conf

if grub-install --version | egrep -q '(1.9|2.0).+' &>/dev/null; then
    sed -i -e \
        's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1"/g' \
        /etc/default/grub
else
    sed -i -e \
        's/#.defoptions=\(.*\)/# defoptions=\1 ipv6.disable=1/' \
        /boot/grub/menu.lst
fi
