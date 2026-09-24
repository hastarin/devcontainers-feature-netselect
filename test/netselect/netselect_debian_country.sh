#!/bin/bash
set -e
source "$(dirname "$0")/_assert.sh"

echo "Selected: $(grep -m1 '^URIs:' /etc/apt/sources.list.d/debian.sources)"

check "default archive replaced" bash -c "! grep -qx 'URIs: http://deb.debian.org/debian' /etc/apt/sources.list.d/debian.sources"
check "security archive unchanged" sources_contain "http://deb.debian.org/debian-security"
check "mirror is in Australia" debian_mirror_in_country AU
check "netselect removed" bash -c "! command -v netselect"
check "apt-get update succeeds" apt_update

reportResults
