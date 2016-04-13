#!/bin/bash

#
# guest-additions.sh
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

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly VMWARE_FILES='/var/tmp/vmware'

# As Packer will upload guest additions to the home directory of the same
# user as the one used for connecting via SSH, we need to check which user
# is it this time.
SYSTEM_USER='vagrant'
if ! getent passwd $SYSTEM_USER &>/dev/null; then
    SYSTEM_USER='ubuntu'
fi

case "$PACKER_BUILDER_TYPE" in
    virtualbox-iso|virtualbox-ovf)
        readonly VBOX_VERSION=$(cat /home/${SYSTEM_USER}/.virtualbox_version)

        mkdir -p /tmp/virtualbox

        mount -t iso9660 -o loop,ro \
            /home/${SYSTEM_USER}/VBoxGuestAdditions_${VBOX_VERSION}.iso \
            /tmp/virtualbox

        export REMOVE_INSTALLATION_DIR=0
        yes 2>/dev/null </dev/null | bash /tmp/virtualbox/VBoxLinuxAdditions.run --nox11 2>&1

        umount /tmp/virtualbox

        ln -s -f \
            /opt/VBoxGuestAdditions-${VBOX_VERSION}/lib/VBoxGuestAdditions \
            /usr/lib/VBoxGuestAdditions

        rm -rf /home/${SYSTEM_USER}/.{vbox,virtualbox}_version \
               /tmp/virtualbox
    ;;

    vmware-iso|vmware-vmx)
        # The patch that fixes build-time error with the VMWare Tools HGFS
        # file system on Debian and/or Ubuntu as their kernels include
        # quite a few back-ported patches from newer Linux kernels,
        # see: https://github.com/rasa/vmware-tools-patches
        PATCH_FILE='vmhgfs-d_alias-kernel-3.18.1-tools-9.9.0.patch'

        [[ -d $VMWARE_FILES ]] || mkdir -p $VMWARE_FILES
        if [[ ! -f ${VMWARE_FILES}/${PATCH_FILE} ]]; then
            wget --no-check-certificate -O ${VMWARE_FILES}/${PATCH_FILE} \
                https://raw.githubusercontent.com/rasa/vmware-tools-patches/master/patches/vmhgfs/04-${PATCH_FILE}
        fi

        mkdir -p /tmp/vmware /tmp/vmware-archive

        mount -t iso9660 -o loop,ro /home/${SYSTEM_USER}/linux.iso /tmp/vmware

        tar -xzf /tmp/vmware/VMwareTools-*.tar.gz -C /tmp/vmware-archive
        pushd /tmp/vmware-archive/vmware-tools-distrib/lib/modules/source &>/dev/null

        tar -xf vmhgfs.tar
        pushd vmhgfs-only &>/dev/null

        # VMWare Tools HGFS module fails to compile on newer kernels,
        # see: https://github.com/rasa/vmware-tools-patches/issues/29
        for option in '--dry-run -s -i' '-i'; do
            # Note: This is expected to fail to apply cleanly on a sufficiently
            # up-to-date version of VMWare Tools.
            if ! patch -l -t -p1 $option ${VMWARE_FILES}/${PATCH_FILE}; then
                break
            fi
        done

        popd &> /dev/null
        tar -cf vmhgfs.tar vmhgfs-only

        popd &>/dev/null
        /tmp/vmware-archive/vmware-tools-distrib/vmware-install.pl -d
        umount /tmp/vmware

        rm -rf /tmp/vmware \
               /tmp/vmware-archive \
               ${VMWARE_FILES}/${PATCH_FILE}
    ;;

    *)
        exit 1
    ;;
esac

rm -f /tmp/*.iso /home/${SYSTEM_USER}/*.iso