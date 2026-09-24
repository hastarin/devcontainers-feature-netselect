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

# Succeeds if the Debian archive mirror in debian.sources is listed in Debian's official
# mirror list (Site or Aliases) under country code $1, e.g. AU.
debian_mirror_in_country() {
    local host
    host="$(sed -nE 's#^URIs: [a-z+]+://([^/:]+).*#\1#p' /etc/apt/sources.list.d/debian.sources | head -n 1)"
    curl -fsSL https://mirror-master.debian.org/status/Mirrors.masterlist |
        mirror_country "$host" | grep -qx "$1"
}

# Reads Mirrors.masterlist on stdin; prints the country code of site $1.
mirror_country() {
    awk -v RS= -v host="$1" '{
        count = split($0, lines, "\n")
        found = 0
        country = ""
        for (i = 1; i <= count; i++) {
            if (lines[i] == "Site: " host) found = 1
            if (lines[i] ~ /^Aliases:/) {
                aliases = split(substr(lines[i], 9), names, /[ \t]+/)
                for (j = 1; j <= aliases; j++) if (names[j] == host) found = 1
            }
            if (lines[i] ~ /^Country:/) { split(lines[i], parts, /[ \t]+/); country = parts[2] }
        }
        if (found) { print country; exit }
    }'
}
