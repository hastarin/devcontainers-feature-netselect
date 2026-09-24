#!/usr/bin/env bash
# Unit tests for src/netselect/lib.sh. No network or root required.
# Run from the repo root: test/netselect/unit/lib_test.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
# shellcheck source=../../../src/netselect/lib.sh
source "${REPO_ROOT}/src/netselect/lib.sh"

FAILURES=0
TESTS=0

pass() { TESTS=$((TESTS + 1)); echo "ok - $1"; }
fail() { TESTS=$((TESTS + 1)); FAILURES=$((FAILURES + 1)); echo "not ok - $1"; }

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$name"
    else
        fail "$name"
        diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/#   /' || true
    fi
}

assert_status() {
    local name="$1" expected="$2"
    shift 2
    local actual=0
    "$@" >/dev/null 2>&1 || actual=$?
    if [ "$expected" = "$actual" ]; then pass "$name"; else fail "$name (exit ${actual}, want ${expected})"; fi
}

# Each test gets a fresh fake /etc/apt.
new_apt_dir() {
    APT_DIR="$(mktemp -d)"
    mkdir -p "${APT_DIR}/sources.list.d"
    export APT_DIR
}

# --- Fixtures taken verbatim from the official images ---------------------

debian_deb822() {
    cat <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: trixie-security
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp
EOF
}

debian_legacy() {
    cat <<'EOF'
deb http://deb.debian.org/debian bullseye main
deb http://deb.debian.org/debian-security bullseye-security main
deb http://deb.debian.org/debian bullseye-updates main
# deb-src http://deb.debian.org/debian bullseye main
deb-src http://deb.debian.org/debian bullseye main
EOF
}

ubuntu_deb822() {
    cat <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
}

ubuntu_legacy() {
    cat <<'EOF'
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted
deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted
EOF
}

ubuntu_ports_deb822() {
    cat <<'EOF'
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
}

# --- rewrite_archive_uri ---------------------------------------------------

test_ubuntu_ports_deb822_security_stanza_untouched() {
    new_apt_dir
    ubuntu_ports_deb822 >"${APT_DIR}/sources.list.d/ubuntu.sources"
    rewrite_archive_uri ports.ubuntu.com/ubuntu-ports http://mirror.example/ubuntu-ports/
    assert_eq "ubuntu ports deb822: only the non-security stanza is rewritten" \
        "$(ubuntu_ports_deb822 | sed '2s#.*#URIs: http://mirror.example/ubuntu-ports/#')" \
        "$(cat "${APT_DIR}/sources.list.d/ubuntu.sources")"
}

test_ubuntu_ports_legacy_security_line_untouched() {
    new_apt_dir
    cat >"${APT_DIR}/sources.list" <<'EOF'
deb http://ports.ubuntu.com/ubuntu-ports/ jammy main
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-security main
EOF
    rewrite_archive_uri ports.ubuntu.com/ubuntu-ports http://mirror.example/ubuntu-ports/
    assert_eq "ubuntu ports legacy: security line untouched" \
        "deb http://mirror.example/ubuntu-ports/ jammy main
deb http://ports.ubuntu.com/ubuntu-ports/ jammy-security main" \
        "$(cat "${APT_DIR}/sources.list")"
}

test_deb822_multiple_uris() {
    new_apt_dir
    printf 'Types: deb\nURIs: http://other.example/debian http://deb.debian.org/debian/\nSuites: trixie\n' \
        >"${APT_DIR}/sources.list.d/debian.sources"
    rewrite_archive_uri deb.debian.org/debian http://m.example/debian
    assert_eq "deb822: only the matching URI in a multi-URI line is replaced" \
        "URIs: http://other.example/debian http://m.example/debian" \
        "$(grep '^URIs:' "${APT_DIR}/sources.list.d/debian.sources")"
}

test_file_mode_preserved() {
    new_apt_dir
    debian_deb822 >"${APT_DIR}/sources.list.d/debian.sources"
    chmod 0644 "${APT_DIR}/sources.list.d/debian.sources"
    rewrite_archive_uri deb.debian.org/debian http://m.example/debian
    assert_eq "file mode preserved" 644 "$(stat -c %a "${APT_DIR}/sources.list.d/debian.sources")"
}

test_debian_deb822() {
    new_apt_dir
    debian_deb822 >"${APT_DIR}/sources.list.d/debian.sources"
    assert_status "debian deb822: reports a change" 0 \
        rewrite_archive_uri deb.debian.org/debian http://ftp.au.debian.org/debian
    assert_eq "debian deb822: archive rewritten, security untouched" \
        "$(debian_deb822 | sed 's#^URIs: http://deb.debian.org/debian$#URIs: http://ftp.au.debian.org/debian#')" \
        "$(cat "${APT_DIR}/sources.list.d/debian.sources")"
}

test_debian_legacy() {
    new_apt_dir
    debian_legacy >"${APT_DIR}/sources.list"
    rewrite_archive_uri deb.debian.org/debian http://ftp.au.debian.org/debian/
    assert_eq "debian legacy: deb and deb-src rewritten, security and comments untouched" \
        "deb http://ftp.au.debian.org/debian/ bullseye main
deb http://deb.debian.org/debian-security bullseye-security main
deb http://ftp.au.debian.org/debian/ bullseye-updates main
# deb-src http://deb.debian.org/debian bullseye main
deb-src http://ftp.au.debian.org/debian/ bullseye main" \
        "$(cat "${APT_DIR}/sources.list")"
}

test_ubuntu_deb822_mirror_method() {
    new_apt_dir
    : >"${APT_DIR}/sources.list"
    ubuntu_deb822 >"${APT_DIR}/sources.list.d/ubuntu.sources"
    rewrite_archive_uri archive.ubuntu.com/ubuntu mirror://mirrors.ubuntu.com/mirrors.txt
    assert_eq "ubuntu deb822: archive rewritten (trailing slash), security untouched" \
        "$(ubuntu_deb822 | sed 's#^URIs: http://archive.ubuntu.com/ubuntu/$#URIs: mirror://mirrors.ubuntu.com/mirrors.txt#')" \
        "$(cat "${APT_DIR}/sources.list.d/ubuntu.sources")"
    assert_eq "ubuntu deb822: empty legacy file left empty" "" "$(cat "${APT_DIR}/sources.list")"
}

test_ubuntu_legacy_with_options() {
    new_apt_dir
    ubuntu_legacy >"${APT_DIR}/sources.list"
    rewrite_archive_uri archive.ubuntu.com/ubuntu http://au.archive.ubuntu.com/ubuntu/
    assert_eq "ubuntu legacy: [options] preserved, security untouched" \
        "deb http://au.archive.ubuntu.com/ubuntu/ jammy main restricted
deb [arch=amd64] http://au.archive.ubuntu.com/ubuntu/ jammy-updates main restricted
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted" \
        "$(cat "${APT_DIR}/sources.list")"
}

test_https_source_matched() {
    new_apt_dir
    echo "URIs: https://deb.debian.org/debian" >"${APT_DIR}/sources.list.d/debian.sources"
    rewrite_archive_uri deb.debian.org/debian http://mirror.example/debian
    assert_eq "https source is matched" "URIs: http://mirror.example/debian" \
        "$(cat "${APT_DIR}/sources.list.d/debian.sources")"
}

test_idempotent_with_cache_url() {
    new_apt_dir
    debian_deb822 >"${APT_DIR}/sources.list.d/debian.sources"
    local cache=http://cache:3142/deb.debian.org/debian
    rewrite_archive_uri deb.debian.org/debian "$cache"
    assert_status "apt-cacher-ng URL is not re-matched on a second run" 1 \
        rewrite_archive_uri deb.debian.org/debian "$cache"
    assert_eq "apt-cacher-ng URL written once" "URIs: ${cache}" \
        "$(grep -m1 '^URIs:' "${APT_DIR}/sources.list.d/debian.sources")"
}

test_no_match() {
    new_apt_dir
    echo "URIs: http://mirror.example/debian" >"${APT_DIR}/sources.list.d/debian.sources"
    assert_status "no matching source returns 1" 1 \
        rewrite_archive_uri deb.debian.org/debian http://ftp.au.debian.org/debian
}

test_no_source_files() {
    new_apt_dir
    assert_status "no source files returns 1" 1 \
        rewrite_archive_uri deb.debian.org/debian http://ftp.au.debian.org/debian
}

# --- valid_mirror_url ------------------------------------------------------

test_valid_mirror_url() {
    local url
    for url in http://ftp.au.debian.org/debian https://mirror.aarnet.edu.au/pub/ubuntu/archive/ \
        http://cache:3142/deb.debian.org/debian mirror://mirrors.ubuntu.com/mirrors.txt \
        mirror+https://example.com/list.txt; do
        assert_status "valid mirror: ${url}" 0 valid_mirror_url "$url"
    done
    for url in "" "ftp.au.debian.org/debian" "http://a b" "http://x/#frag" "http://x/a&b" \
        'http://x/a\b' "http://x/a|b" "HTTP://X/"; do
        assert_status "invalid mirror: '${url}'" 1 valid_mirror_url "$url"
    done
}

# --- ubuntu_archive_path ---------------------------------------------------

test_ubuntu_archive_path() {
    assert_eq "ubuntu archive: amd64" archive.ubuntu.com/ubuntu "$(ubuntu_archive_path amd64)"
    assert_eq "ubuntu archive: i386" archive.ubuntu.com/ubuntu "$(ubuntu_archive_path i386)"
    assert_eq "ubuntu archive: arm64" ports.ubuntu.com/ubuntu-ports "$(ubuntu_archive_path arm64)"
}

# --- parse_netselect_apt_output --------------------------------------------

test_parse_netselect_apt_output() {
    local out
    out="$(mktemp)"
    cat >"$out" <<'EOF'
# Debian packages for trixie
deb http://mirror.aarnet.edu.au/debian/ trixie main
# Uncomment the deb-src line if you want 'apt-get source'
# to work with most packages.
# deb-src http://mirror.aarnet.edu.au/debian/ trixie main
EOF
    assert_eq "netselect-apt output parsed" http://mirror.aarnet.edu.au/debian/ \
        "$(parse_netselect_apt_output "$out")"
    : >"$out"
    assert_eq "empty netselect-apt output gives empty mirror" "" "$(parse_netselect_apt_output "$out")"
}

for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do
    "$t"
done

echo "# ${TESTS} tests, ${FAILURES} failures"
[ "$FAILURES" -eq 0 ]
