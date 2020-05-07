#!/bin/bash

set -e

export PATH='/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'

readonly SWAP_UUID=$(blkid -o value -l -s UUID -t TYPE=swap)
readonly SWAP_PARTITION=$(readlink -f "/dev/disk/by-uuid/${SWAP_UUID}")

# Zero the swap partition and re-initialize.
if [[ -n $SWAP_UUID ]]; then
    swapoff "$SWAP_PARTITION"
    dd if=/dev/zero of="${SWAP_PARTITION}" bs=1M || true
    mkswap -U "$SWAP_UUID" "$SWAP_PARTITION"
    sync
fi

# Zero the root partition to reclaim deleted space (allocations). This
# will enable the resulting image to have better compression ratio.
dd if=/dev/zero of=/empty.file bs=1M || true
rm -f /empty.file
sync
