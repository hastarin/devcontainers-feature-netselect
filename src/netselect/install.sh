#!/usr/bin/env bash
# Points apt's primary archive at a nearby or explicitly chosen mirror.
# Security archives are never changed.

set -euo pipefail
# Also abort on failures inside $(...), e.g. in select_debian_mirror.
shopt -s inherit_errexit

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

MIRROR="${MIRROR:-}"
COUNTRY="${COUNTRY:-default}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Installs any of the given packages that are missing, and prints the ones it installed.
install_missing_packages() {
    local package missing=()
    for package in "$@"; do
        if ! dpkg -s "$package" >/dev/null 2>&1; then
            missing+=("$package")
        fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        return
    fi
    if [ -z "$(find /var/lib/apt/lists -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        echo "Running apt-get update..." >&2
        apt-get update -y >&2
    fi
    apt-get -y install --no-install-recommends "${missing[@]}" >&2
    printf '%s\n' "${missing[@]}"
}

# Uses netselect-apt to pick the lowest-latency Debian mirror carrying this
# architecture, and prints its URL. netselect needs raw sockets and is only useful at
# build time, so it is removed afterwards if this script installed it.
select_debian_mirror() {
    local output installed package args=()
    installed="$(install_missing_packages netselect netselect-apt curl ca-certificates)"

    output="$(mktemp)"
    args=(-o "$output" -a "$ARCH")
    if [ -n "$COUNTRY" ] && [ "$COUNTRY" != "default" ]; then
        echo "(*) Only considering mirrors in country '${COUNTRY}'" >&2
        args+=(-c "$COUNTRY")
    fi
    # netselect-apt's exit status is unreliable; success is judged by whether it wrote a mirror.
    netselect-apt "${args[@]}" >&2 || true
    parse_netselect_apt_output "$output"
    rm -f "$output"

    local tools=()
    for package in netselect netselect-apt; do
        if grep -qx "$package" <<<"$installed"; then
            tools+=("$package")
        fi
    done
    if [ "${#tools[@]}" -gt 0 ]; then
        apt-get -y purge --auto-remove "${tools[@]}" >&2
    fi
}

# shellcheck source=/dev/null
. /etc/os-release
case "$ID" in
    debian | ubuntu) ARCH="$(dpkg --print-architecture)" ;;
    *)
        echo "(!) Unsupported distribution '${ID}'; leaving apt sources unchanged."
        exit 0
        ;;
esac
if [ "$ID" = "debian" ]; then
    ARCHIVE="deb.debian.org/debian"
else
    ARCHIVE="$(ubuntu_archive_path "$ARCH")"
fi

if [ -n "$MIRROR" ]; then
    SELECTED="$MIRROR"
elif [ "$ID" = "debian" ]; then
    echo "(*) Selecting the fastest Debian mirror with netselect-apt"
    SELECTED="$(select_debian_mirror)"
    if [ -z "$SELECTED" ]; then
        echo "(!) netselect-apt did not select a mirror (it needs outbound ICMP/UDP). Set the 'mirror' option to choose one."
        exit 1
    fi
elif [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then
    SELECTED="mirror://mirrors.ubuntu.com/mirrors.txt"
else
    echo "(!) mirrors.ubuntu.com has no ${ARCH} mirrors; set the 'mirror' option to choose one. Leaving apt sources unchanged."
    exit 0
fi

if ! valid_mirror_url "$SELECTED"; then
    echo "(!) Invalid mirror URL '${SELECTED}'. Expected e.g. http://ftp.au.debian.org/debian"
    exit 1
fi

echo "(*) Replacing ${ARCHIVE} with ${SELECTED}"
if ! rewrite_archive_uri "$ARCHIVE" "$SELECTED"; then
    echo "(!) No apt source uses ${ARCHIVE}; nothing changed."
fi

# Package lists fetched above came from the old mirror.
rm -rf /var/lib/apt/lists/*

echo "Done!"
