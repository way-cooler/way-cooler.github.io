#!/bin/sh
set -eo pipefail
IFS=$'\n\t'

function assert_file_exists() {
    if ! [ -f "$1" ]; then
        echo -e "\e[31mCould not find file \"$1\", halting...\e[0m"
        exit 1
    fi
}

assert_file_exists "way-cooler"
assert_file_exists "way-cooler-bg"

if ! [[ $(id -u) = 0 ]] && ! [[ $# == 1 ]]; then
    echo -e "\e[31mThe install script will be ran as root!"
    echo -e "\e[0m"
    echo "Please provide your password so that installation can commence:"
    exec sudo -- "$0" "$@"
fi

install_path=$1;
: ${install_path:='/usr/bin'}
[ -d $install_path ] || mkdir $install_path

echo "Installing to $install_path..."

echo "Installing $install_path/way-cooler"
cp way-cooler $install_path
echo "Installing $install_path/way-cooler-bg"
cp way-cooler-bg $install_path

chown $USER $install_path/way-cooler
chgrp $USER $install_path/way-cooler
chown $USER $install_path/way-cooler-bg
chgrp $USER $install_path/way-cooler-bg

if ! [[ $(pidof systemd) ]] && [[ $(id -u) = 0 ]]; then
    echo "systemd is not installed on this machine, activating the setuid bit on $install_path/way-cooler"
    chmod u+s $install_path/way-cooler
fi

echo -e "\e[32mWay Cooler has been installed on your system\e[0m"
