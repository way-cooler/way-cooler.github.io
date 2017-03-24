#!/usr/bin/sh

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
SECOND_STAGE_URL=https://way-cooler.github.io/install.sh

mkdir $TMP_DIR

echo "Fetching way-cooler..."
curl -fsSL $WM_URL > $TMP_DIR/way-cooler || cleanup
echo "Fetching way-cooler-bg..."
curl -fsSL $BG_URL > $TMP_DIR/way-cooler-bg || cleanup
echo "Fetching wc-grab..."
curl -fsSL $GRAB_URL > $TMP_DIR/way-cooler-bg || cleanup
echo "Fetching second stage install script..."
curl -fsSL $SECOND_STAGE_URL > $TMP_DIR/install.sh || cleanup

chmod a+x $TMP_DIR/install.sh

echo "Starting second stage"
(cd $TMP_DIR; ./install.sh)
cleanup

