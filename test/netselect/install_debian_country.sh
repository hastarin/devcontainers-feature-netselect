#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "mirror.txt exists" cat /tmp/mirror.txt
check "sources.list" cat /etc/apt/sources.list
check "sources.list updated" grep ".ca" /etc/apt/sources.list

# Report result
reportResults