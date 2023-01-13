#!/usr/bin/env bash

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            apt-get update -y
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

check_packages sed curl wget ca-certificates

install() {
    . /etc/os-release 

    if [[ "$ID" == "debian" ]]; then
        echo "(*) Configuring fastest mirror using netselect"
        check_packages netselect netselect-apt
        if [[ "$COUNTRY" == "default" ]]; then
            netselect-apt
        else
            echo "Using country code of $COUNTRY"
            netselect-apt -c $COUNTRY
        fi
        MIRROR=$(grep "deb " sources.list | head -n 1 | cut -d " " -f 2)
        echo "Configuring mirror with $MIRROR"
        echo $MIRROR > /tmp/mirror.txt
        sed -i "s|^deb http://deb.debian.org/debian |deb $MIRROR |" /etc/apt/sources.list
        rm sources.list
    elif [[ "$ID" == "ubuntu" ]]; then
        echo "(*) Configuring fastest mirror using netselect"
        wget http://ftp.us.debian.org/debian/pool/main/n/netselect/netselect_0.3.ds1-29_amd64.deb
        dpkg -i netselect_0.3.ds1-29_amd64.deb
        MIRROR=$(netselect -s 1 -t 40 $(wget -qO - mirrors.ubuntu.com/mirrors.txt) | tr -s " " | cut -d " " -f 3)
        echo "Configuring mirror with $MIRROR"
        echo $MIRROR > /tmp/mirror.txt
        sed -i "s|^deb http://archive.ubuntu.com/ubuntu/ |deb $MIRROR |" /etc/apt/sources.list
    else
        echo "Unhandled distribution $DIST_ID"
        sleep 30
    fi
}


install

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"