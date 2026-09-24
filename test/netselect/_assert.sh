#!/bin/bash
# Shared assertions for the netselect scenario tests.

# shellcheck source=/dev/null
source dev-container-features-test-lib

all_sources() {
    cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
}

# Succeeds if a non-comment source line contains the literal string $1.
sources_contain() {
    all_sources | grep -v '^[[:space:]]*#' | grep -qF -- "$1"
}

sources_lack() {
    ! sources_contain "$1"
}

# Succeeds if some source line is exactly $1.
sources_have_line() {
    all_sources | grep -qxF -- "$1"
}

# devcontainers/base images run tests as a non-root user with passwordless sudo.
apt_update() {
    if [ "$(id -u)" -eq 0 ]; then apt-get update; else sudo apt-get update; fi
}
