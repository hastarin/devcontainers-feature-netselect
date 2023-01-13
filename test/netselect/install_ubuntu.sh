#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "netselect" which netselect
check "sources.list" cat /etc/apt/sources.list
check "mirror.txt exists" cat /tmp/mirror.txt

# Report result
reportResults