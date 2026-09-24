#!/bin/bash
set -e
source "$(dirname "$0")/_assert.sh"

check "archive uses mirror:// method" sources_contain "mirror://mirrors.ubuntu.com/mirrors.txt"
check "default archive replaced" sources_lack "http://archive.ubuntu.com/ubuntu"
check "security archive unchanged" sources_contain "http://security.ubuntu.com/ubuntu"
check "apt-get update succeeds" apt_update

reportResults
