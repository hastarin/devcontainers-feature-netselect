#!/bin/bash

set -e

# Optional: Import test library
source dev-container-features-test-lib

# Definition specific tests
check "sources.list" cat /etc/apt/sources.list
check "sources.list updated" grep ".au" /etc/apt/sources.list

# Report result
reportResults