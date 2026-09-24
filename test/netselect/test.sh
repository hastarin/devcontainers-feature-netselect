#!/bin/bash

# Run against an auto-generated devcontainer.json using the feature's default options.
# The default base image is Ubuntu, so this exercises the mirror:// path. Run with:
#    devcontainer features test --features netselect --skip-scenarios .
# Scenario tests (scenarios.json) cover explicit mirrors and netselect-apt on Debian.

set -e
source "$(dirname "$0")/_assert.sh"

check "archive uses mirror:// method" sources_contain "mirror://mirrors.ubuntu.com/mirrors.txt"
check "default archive replaced" sources_lack "http://archive.ubuntu.com/ubuntu"

reportResults
