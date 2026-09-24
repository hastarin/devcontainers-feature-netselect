#!/bin/bash
set -e
source "$(dirname "$0")/_assert.sh"

check "archive uses chosen mirror" sources_have_line "URIs: http://ftp.au.debian.org/debian"
check "default archive replaced" bash -c "! grep -qx 'URIs: http://deb.debian.org/debian' /etc/apt/sources.list.d/debian.sources"
check "security archive unchanged" sources_contain "http://deb.debian.org/debian-security"
check "apt-get update succeeds" apt_update

reportResults
