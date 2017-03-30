#!/bin/sh
set -eo pipefail
IFS=$'\n\t'

function cleanup() {
    rm -rf $TMP_DIR
    exit 1
}

WM_VERSION="v0.5.2"
BG_VERSION="v0.1.0"
GRAB_VERSION="v0.1.0"
TMP_DIR=/tmp/way-cooler
WM_URL=https://github.com/way-cooler/way-cooler/releases/download/$WM_VERSION/way-cooler
BG_URL=https://github.com/way-cooler/way-cooler-bg/releases/download/$BG_VERSION/way-cooler-bg
GRAB_URL=https://github.com/way-cooler/way-cooler-grab/releases/download/$GRAB_VERSION/wc-grab

mkdir $TMP_DIR

INSTALL_LIST=($WM_URL)
while test $# -gt 0; do
    case "$1" in
        way-cooler-bg)
            INSTALL_LIST+=($BG_URL)
        ;;
        wc-grab)
            INSTALL_LIST+=($GRAB_URL)
        ;;
        *)
        ;;
    esac
    shift
done
for url in ${INSTALL_LIST[@]}; do
    name=${url##*/}
    echo "Fetching $name..."
    curl -fsSL $url > $TMP_DIR/$name || cleanup
done

echo "Starting second stage"

if ! [[ $(id -u) = 0 ]] && ! [[ $# == 1 ]]; then
    echo -e "\e[31mThe install script will be ran as root!"
    echo -e "\e[0m"
    echo "Please provide your password so that installation can commence:"
    #TODO Readd -k
    exec sudo -- "$0" "$@"
fi

(cd $TMP_DIR;
# We'll enable custom install paths later
#install_path=$1;
: ${install_path:='/usr/bin'}
[ -d $install_path ] || mkdir $install_path

echo "Installing to $install_path..."

for file in *; do
    echo $file
done

echo "Installing $install_path/way-cooler"
cp way-cooler $install_path
echo "Installing $install_path/way-cooler-bg"
cp way-cooler-bg $install_path
echo "Installing $install_path/wc-grab"
cp wc-grab $install_path

chown $USER $install_path/way-cooler
chgrp $USER $install_path/way-cooler
chmod +x $install_path/way-cooler
chown $USER $install_path/way-cooler-bg
chgrp $USER $install_path/way-cooler-bg
chmod +x $install_path/way-cooler-bg
chown $USER $install_path/wc-grab
chgrp $USER $install_path/wc-grab
chmod +x $install_path/wc-grab

if ! [[ $(pidof systemd) ]] && [[ $(id -u) = 0 ]]; then
    echo "systemd is not installed on this machine, activating the setuid bit on $install_path/way-cooler"
    chmod u+s $install_path/way-cooler
fi

echo -e "\e[32mWay Cooler has been installed on your system\e[0m"

)
cleanup
