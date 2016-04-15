#!/bin/bash

#
# itamae.sh
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

# A list of Ruby gems to install alongside Itamae.
GEMS=( specinfra-ec2_metadata-tags )

# By default, assume that latest version of Itamae is stable.
if [[ -n $ITAMAE_VERSION ]]; then
    gem install --no-document --no-suggestions itamae --version ${ITAMAE_VERSION}
else
    gem install --no-document --no-suggestions itamae
fi

for gem in "${GEMS[@]}"; do
    gem install --no-document --no-suggestions $gem
done
