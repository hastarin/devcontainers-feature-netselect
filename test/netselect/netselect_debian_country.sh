#!/bin/bash
set -e
source "$(dirname "$0")/_assert.sh"

check "default archive replaced" bash -c "! grep -qx 'URIs: http://deb.debian.org/debian' /etc/apt/sources.list.d/debian.sources"
check "security archive unchanged" sources_contain "http://deb.debian.org/debian-security"
check "mirror is in Australia" bash -c "grep -E '^URIs: https?://[^/]*\\.au[/:]' /etc/apt/sources.list.d/debian.sources"
check "netselect removed" bash -c "! command -v netselect"
check "apt-get update succeeds" apt_update

reportResults
