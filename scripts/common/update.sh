#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

source /var/tmp/helpers/default.sh

readonly COMMON_FILES='/var/tmp/common'
readonly UBUNTU_RELEASE=$(detect_ubuntu_release)
readonly UBUNTU_VERSION=$(detect_ubuntu_version)
readonly AMAZON_EC2=$(detect_amazon_ec2 && echo 'true')

# Remove current Apt and DPKG overrides ...
rm -f /etc/apt/apt.conf.d/* \
      /etc/dpkg/dpkg.cfg.d/*

cat <<'EOF' > /etc/apt/apt.conf.d/99trustcdrom
APT
{
    Authentication
    {
        TrustCDROM "false":
    };
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99apt
APT
{
    Color "0";
    Install-Suggests "0";
    Install-Recommends "0";
    Clean-Installed "0";

    AutoRemove
    {
        SuggestsImportant "0";
    };

    Get
    {
        AllowUnauthenticated "0";
    };
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99vendor-ubuntu
Acquire
{
    Changelogs
    {
        AlwaysOnline "1";
    };
};
EOF

# Any Amazon EC2 instance can use local packages mirror, but quite often
# such mirrors are backed by an S3 buckets causing performance drop due
# to a known problem outside of the "us-east-1" region when using HTTP
# pipelining for more efficient downloads.
PIPELINE_DEPTH=5
if [[ -n $AMAZON_EC2 ]]; then
     PIPELINE_DEPTH=3
fi

cat <<EOF > /etc/apt/apt.conf.d/99apt-acquire
Acquire
{
    PDiffs "0";

    Retries "3";
    Queue-Mode "access";
    Check-Valid-Until "0";

    ForceIPv4 "1";

    http
    {
        Timeout "120";
        Pipeline-Depth "${PIPELINE_DEPTH}";

        No-cache "0";
        Max-Age "86400";
        No-store "0";
    };

    Languages "none";

    GzipIndexes "1";
    CompressionTypes
    {
        Order
        {
            "gz";
        };
    };
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99update-stamp
APT
{
    Update
    {
        Post-Invoke-Success
        {
            "touch /var/lib/apt/periodic/update-success-stamp 2>/dev/null || true";
        };
    };
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99apt-autoremove
APT
{
    NeverAutoRemove
    {
	"^firmware-linux.*";
	"^linux-firmware$";
    };

    VersionedKernelPackages
    {
	"linux-image";
	"linux-headers";
	"linux-image-extra";
	"linux-signed-image";
	"kfreebsd-image";
	"kfreebsd-headers";
	"gnumach-image";
	".*-modules";
	".*-kernel";
	"linux-backports-modules-.*";
        "linux-tools";
    };

    Never-MarkAuto-Sections
    {
	"metapackages";
	"contrib/metapackages";
	"non-free/metapackages";
	"restricted/metapackages";
	"universe/metapackages";
	"multiverse/metapackages";
    };

    Move-Autobit-Sections
    {
        "oldlibs";
        "contrib/oldlibs";
        "non-free/oldlibs";
        "restricted/oldlibs";
        "universe/oldlibs";
        "multiverse/oldlibs";
    };
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99dpkg-progress
DPkg
{
    Progress-Fancy "0";
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99dpkg-pre-install
DPkg
{
    Pre-Install-Pkgs
    {
        "/usr/sbin/dpkg-preconfigure --apt || true" ;
    };
}
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99dpkg
DPkg
{
    Options
    {
        "--force-confdef";
        "--force-confnew";
    };
};
EOF

cat <<'EOF' > /etc/apt/apt.conf.d/99cache
Dir
{
    Cache
    {
        pkgcache "";
        srcpkgcache "";
    };
};
EOF

cat <<'EOF' > /etc/dpkg/dpkg.cfg.d/99exclude-documentation
path-exclude /usr/share/doc/*
path-exclude /usr/share/man/*
path-exclude /usr/share/info/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*
EOF

cat <<'EOF' > /etc/dpkg/dpkg.cfg.d/99locales
path-exclude /usr/share/locale/*
path-include /usr/share/locale/en*
EOF

cat <<'EOF' > /etc/dpkg/dpkg.cfg.d/99apt-speedup
force-unsafe-io
EOF

chown root: /etc/apt/apt.conf.d/* \
            /etc/dpkg/dpkg.cfg.d/*

chmod 644 /etc/apt/apt.conf.d/* \
          /etc/dpkg/dpkg.cfg.d/*

# Make sure that Apt updates are consistent...
dpkg-divert --divert /etc/apt/apt.conf.d/99apt-autoremove \
            --rename /etc/apt/apt.conf.d/01autoremove

dpkg-divert --divert /etc/apt/apt.conf.d/99vendor-ubuntu \
            --rename /etc/apt/apt.conf.d/01-vendor-ubuntu

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get --assume-yes clean all
    rm -rf /var/lib/apt/lists
fi

# Ubuntu (up to) 12.04 require a third-party repository
# to install latest version of the OpenSSH Server.
if [[ $UBUNTU_VERSION == '12.04' ]]; then
    cat << 'EOF' > /etc/apt/sources.list.d/precise-backports.list
deb http://ppa.launchpad.net/natecarlson/precisebackports/ubuntu precise main
deb-src http://ppa.launchpad.net/natecarlson/precisebackports/ubuntu precise main
EOF

    chown root: /etc/apt/sources.list.d/precise-backports.list
    chmod 644 /etc/apt/sources.list.d/precise-backports.list

    if [[ ! -f "${COMMON_FILES}/precise-backports.key" ]]; then
        # Fetch Nate Carlson's PPA key from the key server.
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3DD9F856
    else
        apt-key add "${COMMON_FILES}/precise-backports.key"
    fi
fi

# Add fix for APT hash sum mismatch.
if [[ $UBUNTU_VERSION =~ ^(12|14) ]]; then
    cat <<EOF > /etc/apt/sources.list.d/apt-backport.list
deb https://packagecloud.io/computology/apt-backport/ubuntu $UBUNTU_RELEASE main
deb-src https://packagecloud.io/computology/apt-backport/ubuntu $UBUNTU_RELEASE main
EOF

    chown root: /etc/apt/sources.list.d/apt-backport.list
    chmod 644 /etc/apt/sources.list.d/apt-backport.list

    if [[ ! -f "${COMMON_FILES}/apt-backport.key" ]]; then
        # Fetch Computology's key from the key server.
        wget -O "${COMMON_FILES}/apt-backport.key" \
            https://packagecloud.io/computology/apt-backport/gpgkey
    fi

    apt-key add "${COMMON_FILES}/apt-backport.key"
fi

# By default, the "cloud-init" will override the default mirror when run as
# Amazon EC2 instance, thus we replace this file only when building Vagrant
# boxes.
if [[ -z $AMAZON_EC2 ]]; then
    # Render template overriding default list.
    eval "echo \"$(cat /var/tmp/vagrant/sources.list.template)\"" \
        > /etc/apt/sources.list

    chown root: /etc/apt/sources.list
    chmod 644 /etc/apt/sources.list

    rm -f /var/tmp/vagrant/sources.list.template
else
    # Allow some grace time for the "cloud-init" to finish
    # and to override the default package mirror.
    for n in {1..30}; do
        echo 'Waiting for cloud-init to finish ...'

        if test -f /var/lib/cloud/instance/boot-finished; then
            break
        else
            # Wait a little longer every time.
            sleep $n
        fi
    done
fi

if [[ -f /etc/update-manager/release-upgrades ]]; then
  sed -i -e \
    's/^Prompt=.*$/Prompt=never/' \
     /etc/update-manager/release-upgrades
fi

# Update everything.
apt-get --assume-yes update 1>/dev/null

export UCF_FORCE_CONFFNEW=1
ucf --purge /boot/grub/menu.lst

if [[ $UBUNTU_VERSION == '12.04' ]]; then
    apt-get --assume-yes install libreadline-dev dpkg
fi

# Only install back-ported Kernel on 12.04 and 14.04 ...
if [[ $UBUNTU_VERSION =~ ^(12|14).04$ ]]; then
    # Make sure to select the right release.
    UBUNTU_BACKPORT='xenial'
    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        UBUNTU_BACKPORT='trusty'
    fi

    # Upgrade to latest available back-ported Kernel version.
    for package in '' 'image' 'headers'; do
        PACKAGE_NAME=$(echo \
                "linux-${package}-generic-lts-${UBUNTU_BACKPORT}" | \
                    sed -e 's/\-\+/\-/')

        apt-get --assume-yes install "$PACKAGE_NAME"
    done
else
    # Add necessary depenencies.
    apt-get --assume-yes install "linux-headers-$(uname -r)"
fi

# Update everything ...
apt-get --assume-yes upgrade

# Update everything else ...
if [[ $UBUNTU_VERSION == '16.04' ]]; then
    apt-get --assume-yes full-upgrade
else
    apt-get --assume-yes dist-upgrade
fi

cat <<'EOF' > /etc/timezone
Etc/UTC
EOF

chown root: /etc/timezone
chmod 644 /etc/timezone

dpkg-reconfigure tzdata

mkdir -p /var/lib/locales/supported.d
chown -R root: /var/lib/locales/supported.d
chmod -R 755 /var/lib/locales/supported.d

# This package is needed to suppprt localisation correctly.
apt-get --assume-yes install locales

# Remove current version ...
rm -f /usr/lib/locale/locale-archive

(
    cat <<'EOF'
en_US UTF-8
en_US.UTF-8 UTF-8
en_US.Latin1 ISO-8859-1
en_US.Latin9 ISO-8859-15
en_US.ISO-8859-1 ISO-8859-1
en_US.ISO-8859-15 ISO-8859-15
EOF
) | tee /var/lib/locales/supported.d/en \
        /etc/locale.gen 1>/dev/null

cat <<'EOF' > /var/lib/locales/supported.d/local
en_US.UTF-8 UTF-8
EOF

chown root: /var/lib/locales/supported.d/{en,local} \
            /etc/locale.gen

chmod 644 /var/lib/locales/supported.d/{en,local} \
          /etc/locale.gen

dpkg-reconfigure locales

update-locale \
    LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8:en_US:en"

rm -f /etc/resolvconf/resolv.conf.d/head
touch /etc/resolvconf/resolv.conf.d/head

chown root: /etc/resolvconf/resolv.conf.d/head
chmod 644 /etc/resolvconf/resolv.conf.d/head

NAME_SERVERS=(
    '8.8.8.8' # Google
    '4.2.2.2' # Level3
)

if [[ -n $AMAZON_EC2 ]]; then
    NAME_SERVERS=()
fi

if [[ $PACKER_BUILDER_TYPE =~ ^vmware.*$ ]]; then
    NAME_SERVERS+=( $(route -n | \
        grep -E 'UG[ \t]' | \
            awk '{ print $2 }') )
fi

cat <<EOF | sed -e '/^$/d' > /etc/resolvconf/resolv.conf.d/tail
$(for server in "${NAME_SERVERS[@]}"; do
    echo "nameserver $server"
done)
options timeout:2 attempts:1 rotate single-request-reopen
EOF

chown root: /etc/resolvconf/resolv.conf.d/tail
chmod 644 /etc/resolvconf/resolv.conf.d/tail

resolvconf -u

apt-get --assume-yes install libnss-myhostname

cat <<'EOF' > /etc/nsswitch.conf
passwd:         compat
group:          compat
shadow:         compat

hosts:          files myhostname dns
networks:       files

protocols:      files db
services:       files db
ethers:         files db
rpc:            files db

netgroup:       nis
EOF

chown root: /etc/nsswitch.conf
chmod 644 /etc/nsswitch.conf

update-ca-certificates -v

if [[ -n $AMAZON_EC2 ]]; then
    # The cloud-init package available on Ubuntu 12.04 is too old,
    # and would fail with "None" being a data source.
    DATA_SOURCES=( NoCloud Ec2 None )
    if [[ $UBUNTU_VERSION == '12.04' ]]; then
        DATA_SOURCES=( NoCloud Ec2 )
    fi

    cat <<EOF > /etc/cloud/cloud.cfg.d/90_overrides.cfg
datasource_list: [ $(join $',' "${DATA_SOURCES[@]}" | sed -e 's/,/, /g') ]
EOF

    cat <<'EOF' | tee -a /etc/cloud/cloud.cfg.d/90_overrides.cfg >/dev/null
cloud_config_modules:
  - emit_upstart
  - disk_setup
  - mounts
  - ssh-import-id
  - locale
  - set-passwords
  - grub-dpkg
  - apt-pipelining
  - apt-configure
  - package-update-upgrade-install
  - timezone
  - disable-ec2-metadata
  - runcmd
cloud_final_modules:
  - scripts-vendor
  - scripts-per-once
  - scripts-per-boot
  - scripts-per-instance
  - scripts-user
  - ssh-authkey-fingerprints
  - keys-to-console
  - phone-home
  - final-message
  - power-state-change
mounts:
  - [ ephemeral, null ]
EOF

# Ubuntu specific cloud-init overrides.
    cat <<'EOF' | tee -a /etc/cloud/cloud.cfg.d/90_overrides.cfg >/dev/null
apt_update: false
EOF

    dpkg-reconfigure cloud-init
fi

if dpkg -s ntpdate &>/dev/null; then
    # The patch that fixes the race condition between the nptdate
    # and ntpd which occurs during the system startup (more precisely
    # when the network interface goes up and the helper script at
    # "/etc/network/if-up.d/ntpdate" runs).
    PATCH_FILE='ntpdate-if_up_d.patch'

    pushd /etc/network/if-up.d &>/dev/null

    for option in '--dry-run -s -i' '-i'; do
        # Note: This is expected to fail to apply cleanly on a sufficiently
        # up-to-date version the ntpdate package.
        if ! patch -l -t -p0 $option "${COMMON_FILES}/${PATCH_FILE}"; then
            break
        fi
    done

    popd &> /dev/null
fi

if [[ -d /etc/dhcp ]]; then
    ln -sf /etc/dhcp /etc/dhcp3
fi

# Make sure that /srv exists.
[[ -d /srv ]] || mkdir -p /srv
chown root: /srv
chmod 755 /srv

if [[ -n $AMAZON_EC2 ]]; then
    # Disable Xen framebuffer driver causing 30 seconds boot delay.
cat <<'EOF' > /etc/modprobe.d/blacklist-xen.conf
blacklist xen_fbfront
EOF
fi

cat <<'EOF' > /etc/modprobe.d/blacklist-broken.conf
install intel_rapl /bin/true
blacklist intel_rapl
EOF

cat <<'EOF' > /etc/modprobe.d/blacklist-legacy.conf
install floppy /bin/true
blacklist floppy
install joydev /bin/true
blacklist joydev
install lp /bin/true
blacklist lp
install ppdev /bin/true
blacklist ppdev
install parport /bin/true
blacklist parport
install psmouse /bin/true
blacklist psmouse
install serio_raw /bin/true
blacklist serio_raw
install parport_pc /bin/true
blacklist parport_pc
EOF

cat <<'EOF' > /etc/modprobe.d/blacklist-conntrack.conf
blacklist nf_conntrack_amanda
blacklist nf_conntrack_broadcast
blacklist nf_conntrack_ftp
blacklist nf_conntrack_h323
blacklist nf_conntrack_irc
blacklist nf_conntrack_netbios_ns
blacklist nf_conntrack_netlink
blacklist nf_conntrack_pptp
blacklist nf_conntrack_proto_dccp
blacklist nf_conntrack_proto_gre
blacklist nf_conntrack_proto_sctp
blacklist nf_conntrack_proto_udplite
blacklist nf_conntrack_sane
blacklist nf_conntrack_sip
blacklist nf_conntrack_snmp
blacklist nf_conntrack_tftp
EOF

cat <<'EOF' > /etc/modprobe.d/blacklist-security.conf
install cramfs /bin/true
blacklist cramfs
install freevxfs /bin/true
blacklist freevxfs
install jffs2 /bin/true
blacklist jffs2
install hfs /bin/true
blacklist hfs
install hfsplus /bin/true
blacklist hfsplus
install squashfs /bin/true
blacklist squashfs
install udf /bin/true
blacklist udf
install vfat /bin/true
blacklist vfat
install dccp /bin/false
blacklist dccp
install sctp /bin/false
blacklist sctp
install rds /bin/false
blacklist rds
install tipc /bin/false
blacklist tipc
EOF

cat <<'EOF' > /etc/modprobe.d/blacklist-bluetooth.conf
alias net-pf-31 off
alias bluetooth off
install bluetooth /bin/false
blacklist bluetooth
EOF

chown root: /etc/modprobe.d/*
chmod 644 /etc/modprobe.d/*

# Prevent the lp and rtc modules from being loaded.
sed -i -e \
    '/^lp/d;/^rtc/d' \
    /etc/modules

for package in procps sysfsutils; do
    apt-get --assume-yes install "$package"
done

for directory in /etc/sysctl.d /etc/sysfs.d; do
    if [[ ! -d $directory ]]; then
        mkdir -p "$directory"
        chown root: "$directory"
        chmod 755 "$directory"
    fi
done

find /etc/sysctl.d/*.conf -type f -print0 | \
    xargs -0 sed -i -e '/^#.*/d;/^$/d;s/\(\w\+\)=\(\w\+\)/\1 = \2/'

cat <<'EOF' > /etc/sysctl.conf
#
# /etc/sysctl.conf - Configuration file for setting system variables
# See /etc/sysctl.d/ for additional system variables.
# See sysctl.conf (5) for information.
#
EOF

# Disabled for now, as hese values are too aggressive to consider these a safe defaults:
#   vm.overcommit_ratio = 80 (default: 50)
#   vm.overcommit_memory = 2 (default: 0)
cat <<'EOF' > /etc/sysctl.d/10-virtual-memory.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 80
vm.dirty_background_ratio = 5
vm.dirty_expire_centisecs = 12000
vm.mmap_min_addr = 65536
EOF

cat <<EOF | sed -e '/^$/d' > /etc/sysctl.d/10-network.conf
net.core.default_qdisc = fq_codel
net.core.somaxconn = 1024
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 8192
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_early_retrans = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_local_port_range = 1024 65535
$(if [[ -n $AMAZON_EC2 ]]; then
echo 'net.ipv4.neigh.default.gc_thresh1 = 0'
fi)
EOF

cat <<'EOF' > /etc/sysctl.d/10-network-security.conf
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 256
net.ipv4.tcp_max_tw_buckets = 131072
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.secure_redirects = 1
net.ipv4.conf.default.secure_redirects = 1
EOF

cat <<'EOF' > /etc/sysctl.d/10-magic-sysrq.conf
kernel.sysrq = 0
EOF

cat <<'EOF' > /etc/sysctl.d/10-kernel-security.conf
fs.suid_dumpable = 0
net.core.bpf_jit_enable = 0
kernel.maps_protect = 1
kernel.core_uses_pid = 1
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
kernel.perf_event_paranoid = 2
kernel.yama.ptrace_scope = 1
kernel.kexec_load_disabled = 1
kernel.ftrace_enabled = 0
EOF

cat <<'EOF' > /etc/sysctl.d/10-link-restrictions.conf
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF

cat <<'EOF' > /etc/sysctl.d/10-kernel-panic.conf
kernel.panic = 60
EOF

cat <<'EOF' > /etc/sysctl.d/10-console-messages.conf
kernel.printk = 4 4 1 7
kernel.printk_ratelimit = 5
kernel.printk_ratelimit_burst = 10
EOF

cat <<'EOF' > /etc/sysctl.d/10-kernel-limits.conf
fs.file-max = 262144
kernel.pid_max = 65535
EOF

chown root: /etc/sysctl.conf \
            /etc/sysctl.d

chmod 644 /etc/sysctl.conf \
          /etc/sysctl.d/*

if [[ $UBUNTU_VERSION == '16.04' ]]; then
    systemctl start procps
else
    service procps start
fi

cat <<'EOF' > /etc/sysfs.d/clock_source.conf
devices/system/clocksource/clocksource0/current_clocksource = tsc
EOF

# Adjust the queue size (for a moderate load on the node)
# accordingly when using Receive Packet Steering (RPS)
# functionality (setting the "rps_flow_cnt" accordingly).
for nic in $(ls -1 /sys/class/net | grep -E 'eth*' 2>/dev/null | sort); do
    cat <<EOF | tee -a /etc/sysfs.d/network.conf >/dev/null
class/net/${nic}/tx_queue_len = 5000
class/net/${nic}/queues/rx-0/rps_cpus = f
class/net/${nic}/queues/tx-0/xps_cpus = f
class/net/${nic}/queues/rx-0/rps_flow_cnt = 32768
EOF
done

# Do not add this file when running on EC2 instance, as often when
# the instance is started the device name can be either "/dev/sda"
# or "/dev/xvda" and there is reliable no way to know which one
# is it going to be. Also, probably not an most ideal thing to do
# on EC2, since the storage type may vay significantly.
if [[ -z $AMAZON_EC2 ]]; then
    for block in $(ls -1 /sys/block | grep -E '(sd|xvd|dm).*' 2>/dev/null | sort); do
        NR_REQUESTS="block/${block}/queue/nr_requests = 256"
        SCHEDULER="block/${block}/queue/scheduler = noop"
        if [[ $block =~ ^dm.*$ ]]; then
            NR_REQUESTS=''
            SCHEDULER=''
        fi

        cat <<EOF | sed -e '/^$/d' | tee -a /etc/sysfs.d/disk.conf >/dev/null
block/${block}/queue/add_random = 0
block/${block}/queue/rq_affinity = 2
block/${block}/queue/read_ahead_kb = 256
${NR_REQUESTS}
block/${block}/queue/rotational = 0
${SCHEDULER}
EOF
    done
fi

# Transparent Huge Pages used to be set to "never",
# albeit some workloads benefit from "madvise", thus
# we set it now by default to "madvise".
cat <<'EOF' > /etc/sysfs.d/transparent_hugepage.conf
kernel/mm/transparent_hugepage/enabled = madvise
kernel/mm/transparent_hugepage/defrag = madvise
EOF

# Disable KSM (Kernel Shared Memory) if present,
# to try to mitigate the Row-Hammer attack.
if [[ -f /sys/kernel/mm/ksm ]]; then
    echo 'kernel/mm/ksm/run = 0' > /etc/sysfs.d/ksm.conf
fi

chown root: /etc/sysfs.conf \
            /etc/sysfs.d/*

chmod 644 /etc/sysfs.conf \
          /etc/sysfs.d/*

if [[ $UBUNTU_VERSION == '16.04' ]]; then
    systemctl restart sysfsutils
else
    service sysfsutils restart
fi

# Restrict access to PID directories under "/proc". This will
# make it more difficult for users to gather information about
# the processes of other users. User "root" and users who are
# members of the "sudo" group would not be restricted.
cat <<EOS | sed -e 's/\s\+/\t/g' >> /etc/fstab
proc /proc proc rw,nosuid,nodev,noexec,relatime,hidepid=2,gid=sudo 0 0
EOS

# The "/run/shm" is going to be a symbolic link to "/dev/shm".
cat <<EOS | sed -e 's/\s\+/\t/g' >> /etc/fstab
tmpfs /dev/shm tmpfs rw,nosuid,nodev,noexec,relatime 0 0
EOS

ln -sf /dev/shm /run/shm

chown root: /etc/fstab
chmod 644 /etc/fstab

# Remove support for logging to xconsole.
for option in $'/.*\/dev\/xconsole/,$d' $'$d'; do
    sed -i -e $option \
        /etc/rsyslog.d/50-default.conf
done

chown root: /etc/rsyslog.d/50-default.conf
chmod 644 /etc/rsyslog.d/50-default.conf

if [[ $UBUNTU_VERSION == '16.04' ]]; then
    # A list of services we want to disable and mask in systemd,
    # as these not only pose a security risk, but also delay the
    # total boot time.
    SERVICES_TO_MASK=(
        'bluetooth.target'
        'dev-hugepages.mount'
        'dev-mqueue.mount'
        'plymouth-quit-wait.service'
        'plymouth-start.service'
        'proc-sys-fs-binfmt_misc.automount'
        'proc-sys-fs-binfmt_misc.mount'
        'sys-fs-fuse-connections.mount'
        'sys-kernel-config.mount'
        'sys-kernel-debug.mount'
    )

    for service in "${SERVICES_TO_MASK[@]}"; do
        for option in disable mask; do
            systemctl "$option" "$service"
        done
    done
fi
