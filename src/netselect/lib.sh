#!/usr/bin/env bash
# Helpers for install.sh. Sourcing this file has no side effects, so the
# functions can be unit tested (see test/netselect/unit/lib_test.sh).

# Root of the apt configuration; overridable for tests.
APT_DIR="${APT_DIR:-/etc/apt}"

# Print each apt source file that exists, in both legacy one-line and deb822 formats.
apt_source_files() {
    local file
    for file in "${APT_DIR}/sources.list" "${APT_DIR}"/sources.list.d/*.list "${APT_DIR}"/sources.list.d/*.sources; do
        if [ -f "$file" ]; then
            printf '%s\n' "$file"
        fi
    done
}

# Succeeds if $1 is a URL apt can use and that is safe to splice into a sed replacement.
valid_mirror_url() {
    local pattern='^[a-z][a-z0-9+]*://[^][:space:]#&\\|]+$'
    [[ "$1" =~ $pattern ]]
}

# The primary Ubuntu archive for a dpkg architecture. Only amd64 and i386 live on
# archive.ubuntu.com; everything else is on ports.ubuntu.com.
ubuntu_archive_path() {
    case "$1" in
        amd64 | i386) echo "archive.ubuntu.com/ubuntu" ;;
        *) echo "ports.ubuntu.com/ubuntu-ports" ;;
    esac
}

# deb822: rewrite matching URIs in stanzas whose Suites don't include a *-security suite.
# Plain POSIX awk, as Debian and Ubuntu ship mawk by default.
rewrite_deb822() {
    awk -v old="$1" -v new="$2" '
        function rewrite(line,    uris, count, i, out) {
            count = split(substr(line, 6), uris, /[ \t]+/)
            out = "URIs:"
            for (i = 1; i <= count; i++) {
                if (uris[i] == "") continue
                if (uris[i] ~ ("^https?://" old "/?$")) uris[i] = new
                out = out " " uris[i]
            }
            return out
        }
        function flush(    i) {
            for (i = 1; i <= lines; i++) {
                if (!security && stanza[i] ~ /^URIs:/) stanza[i] = rewrite(stanza[i])
                print stanza[i]
            }
            lines = 0
            security = 0
        }
        /^[ \t]*$/ { flush(); print; next }
        {
            stanza[++lines] = $0
            if ($0 ~ /^Suites:/ && $0 ~ /-security([ \t]|$)/) security = 1
        }
        END { flush() }
    '
}

# One-line format: rewrite deb/deb-src lines, except those for a *-security suite.
rewrite_one_line() {
    sed -E "/^[^#]*[[:space:]][^[:space:]]+-security([[:space:]]|\$)/!s#^((deb|deb-src)([[:space:]]+\\[[^]]*\\])?[[:space:]]+)https?://${1}/?([[:space:]])#\\1${2}\\4#"
}

# Replace the archive at host/path $1 (e.g. deb.debian.org/debian, matched over http or
# https, with or without a trailing slash) with the URL $2 in every apt source file.
# Paths that merely start with $1, such as deb.debian.org/debian-security, and entries
# for *-security suites are left alone. Returns 0 if any file changed, 1 otherwise.
rewrite_archive_uri() {
    local old="${1//./[.]}" new="$2" file rewritten changed=1
    rewritten="$(mktemp)"
    while IFS= read -r file; do
        if [[ "$file" == *.sources ]]; then
            rewrite_deb822 "$old" "$new" <"$file" >"$rewritten"
        else
            rewrite_one_line "$old" "$new" <"$file" >"$rewritten"
        fi
        if ! cmp -s "$file" "$rewritten"; then
            # Overwrite in place to keep the file's owner and mode.
            cat "$rewritten" >"$file"
            changed=0
        fi
    done < <(apt_source_files)
    rm -f "$rewritten"
    return "$changed"
}

# Print the archive URL from the sources.list that netselect-apt writes.
parse_netselect_apt_output() {
    awk '$1 == "deb" { print $2; exit }' "$1"
}
