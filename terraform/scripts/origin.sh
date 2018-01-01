#!/bin/bash

set -e
set -u
set -o pipefail

normalize_boolean() {
    [[ $1 =~ 1|yes|true ]] && echo 'true' || echo 'false'
}

fetch_origin() {
    # List of popular "what is my IP?" providers.
    local hosts=(
        'http://checkip.amazonaws.com/'
        'http://icanhazip.com/'
        'http://ident.me/'
        'http://ifconfig.io/'
        'http://ipecho.net/plain'
        'http://whatismyip.akamai.com/'
    )

    local tries=0
    local origin=''
    local host="${hosts[$(( RANDOM % ${#hosts[@]} ))]}"

    # Try to get an IP address but give up after trying 5 times.
    while [[ -z ${origin} ]] && (( tries < 5 )); do
        set +e
        if which curl &>/dev/null; then
            origin=$(curl --max-time 5 --user-agent 'curl/1.0.0' -L "$host" 2>/dev/null)
        else
            origin=$(wget --timeout 5 --user-agent 'curl/1.0.0' -O- "$host" 2>/dev/null)
        fi
        set -e

        host="${hosts[$(( RANDOM % ${#hosts[@]} ))]}"
        tries=$(( tries + 1 ))
    done

    echo "$origin"
}

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

ADD_CIDR=${ADD_CIDR-}

if ! test -t 0; then
    eval "$(jq -r '@sh "ADD_CIDR=\(.add_cidr)"')"
fi

ORIGIN="$(fetch_origin)"
if [[ $(normalize_boolean "$ADD_CIDR") == 'true' ]]; then
    # Add /32 to the IP address.
    ORIGIN="${ORIGIN}/32"
fi

jq -c -n --arg origin "$ORIGIN" '{ "origin": $origin }'
