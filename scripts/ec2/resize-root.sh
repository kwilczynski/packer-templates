#!/bin/bash

#
# resize-root.sh
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

ROOT_PARTITION='/dev/xvda1'
if [[ ! -b $ROOT_PARTITION ]]; then
    ROOT_PARTITION='/dev/sda1'
fi

# This should not be needed, but just in case
# we attempt to re-size the root partition.
resize2fs -p $ROOT_PARTITION
