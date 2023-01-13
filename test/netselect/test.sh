#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'netselect' feature with no options.
#
# Eg:
# {
#    "image": "<..some-base-image...>",
#    "features": {
#      "netselect": {}
#    }
# }
#
# Thus, the value of all options will fall back to the default value in 
# the feature's 'devcontainer-feature.json'.
# For the 'netselect' feature, that means the no country option will be used.
#
# These scripts are run as 'root' by default. Although that can be changed
# with the --remote-user flag.
# 
# This test can be run with the following command (from the root of this repo)
#    devcontainer features test \ 
#                   --features netselect \
#                   --base-image mcr.microsoft.com/devcontainers/base:ubuntu .

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "netselect" netselect
. /etc/os-release
if [[ "$ID" == "debian" ]]; then
    check "netselect-apt" netselect-apt --help
fi
check "sources.list" cat /etc/apt/sources.list
check "mirror.txt exists" cat /tmp/mirror.txt

# Report result
reportResults