#!/bin/bash

function cleanup {
    rm -rf $TMP_DIR
    exit 1
}

# VERSION NUMBERS
WM_VERSION="v0.7.0"
BG_VERSION="v0.3.0"
GRAB_VERSION="v0.3.0"
LOCK_VERSION="v0.2.1"

TMP_DIR=/tmp/way-cooler
WM_URL=https://github.com/way-cooler/way-cooler/releases/download/$WM_VERSION/way-cooler
BG_URL=https://github.com/way-cooler/way-cooler-bg/releases/download/$BG_VERSION/wc-bg
GRAB_URL=https://github.com/way-cooler/way-cooler-grab/releases/download/$GRAB_VERSION/wc-grab
LOCK_URL=https://github.com/way-cooler/way-cooler-lock/releases/download/$LOCK_VERSION/wc-lock
LOCK_PAM_URL=https://github.com/way-cooler/way-cooler-lock/releases/download/$LOCK_VERSION/wc-lock-pam
SECOND_STAGE_URL=https://way-cooler.github.io/install.sh

mkdir $TMP_DIR

echo "Fetching second stage install script..."
curl -fsSL $SECOND_STAGE_URL > $TMP_DIR/install.sh || cleanup

chmod a+x $TMP_DIR/install.sh

INSTALL_LIST=($WM_URL)
while test $# -gt 0; do
    case "$1" in
        way-cooler-bg)
            INSTALL_LIST+=($BG_URL)
            ;;
        wc-grab)
            INSTALL_LIST+=($GRAB_URL)
            ;;
        wc-lock)
            INSTALL_LIST+=($LOCK_URL)
            INSTALL_LIST+=($LOCK_PAM_URL)
            ;;
        *)
            echo -e "\e[93mUnknown program $1! Skipping...\e[0m"
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
(cd $TMP_DIR; ./install.sh || cleanup)
cleanup

