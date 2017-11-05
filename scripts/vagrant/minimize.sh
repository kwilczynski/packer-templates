#!/bin/bash

#
# minimize.sh
#
# Copyright 2016-2017 Krzysztof Wilczynski
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
set -o pipefail

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

readonly SWAP_UUID=$(blkid -o value -l -s UUID -t TYPE=swap)
readonly SWAP_PARTITION=$(readlink -f "/dev/disk/by-uuid/${SWAP_UUID}")

# Zero the swap partition and re-initialize.
swapoff $SWAP_PARTITION
dd if=/dev/zero of=${SWAP_PARTITION} bs=1M || true
mkswap -U $SWAP_UUID $SWAP_PARTITION
sync

# Zero the root partition to reclaim deleted space (allocations). This
# will enable the resulting image to have better compression ratio.
dd if=/dev/zero of=/empty.file bs=1M || true
rm -f /empty.file
sync
