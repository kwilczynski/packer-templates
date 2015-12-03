#!/bin/bash

set -e

_select_platform() {
    case "$(uname -m)" in
        x86|i?86)
            echo i386;
        ;;
        x86_64|amd64)
            echo amd64;
        ;;
    esac
}

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly CHEF_FILES='/var/tmp/chef'

[[ -d $CHEF_FILES ]] || mkdir -p $CHEF_FILES

# The Chef Client package might already exist - and if so, then omit
# downloading it from the Internet again since it can take a while.
CHEF_CLIENT_PACKAGE="${CHEF_FILES}/chef_${CHEF_CLIENT_VERSION}-1_$(_select_platform).deb"
if [[ -f $CHEF_CLIENT_PACKAGE ]]; then
    dpkg -i $CHEF_CLIENT_PACKAGE
else
    if [[ ! -f ${CHEF_FILES}/install.sh ]]; then
        wget --no-check-certificate -O ${CHEF_FILES}/install.sh \
            https://www.opscode.com/chef/install.sh
    fi

    # Add any extra options to pass to the Omnibus Installer.
    # See: https://docs.chef.io/install_omnibus.html
    OMNIBUS_OPTIONS=''
    if [[ -n $CHEF_CLIENT_VERSION ]]; then
        OMNIBUS_OPTIONS+=" -v ${CHEF_CLIENT_VERSION}"
    fi

    $SHELL ${CHEF_FILES}/install.sh $OMNIBUS_OPTIONS
fi

rm -rf $CHEF_FILES
