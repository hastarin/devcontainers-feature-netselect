#!/bin/bash
set -e
source "$(dirname "$0")/_assert.sh"

check "archive uses chosen mirror" sources_contain "http://ftp.au.debian.org/debian "
check "default archive replaced" sources_lack "http://deb.debian.org/debian "
check "security archive unchanged" sources_contain "http://deb.debian.org/debian-security"
check "apt-get update succeeds" apt_update

reportResults
