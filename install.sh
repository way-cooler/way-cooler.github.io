#!/bin/bash
set -eo pipefail
IFS=$'\n\t'

if ! [[ $(id -u) = 0 ]] && ! [[ $# == 1 ]]; then
    echo -e "\e[31mThe install script will be ran as root!"
    echo -e "\e[0m"
    echo "Please provide your password so that installation can commence:"
    exec sudo -k -- "$0" "$@"
fi

# We'll enable custom install paths later
#install_path=$1;
: ${install_path:='/usr/bin'}
[ -d $install_path ] || mkdir $install_path

echo "Installing to $install_path..."

for file in *; do
    if [ "./$file" != $0 ]; then
        # TODO Hack to install wc-lock pam file
        # wc-lock should have its own install script that does this, and
        # it should be called.
        if [ "./$file" == "./wc-lock-pam" ]; then
            echo "Installing wc-lock to /etc/pam.d/"
            cp $file /etc/pam.d/
            mv /etc/pam.d/$file /etc/pam.d/wc-lock
            chmod 0644 /etc/pam.d/wc-lock
            continue;
        fi
        echo "Installing $file to $install_path/$file"
        cp $file $install_path
        chown $USER $install_path/$file
        chgrp $USER $install_path/$file
        chmod +x $install_path/$file

        echo -e "\e[32m$file has been installed on your system\e[0m"
    fi
done

if ! [[ $(pidof systemd) ]] && [[ $(id -u) = 0 ]]; then
    echo "systemd is not installed on this machine, activating the setuid bit on $install_path/way-cooler"
    chmod u+s $install_path/way-cooler
fi
