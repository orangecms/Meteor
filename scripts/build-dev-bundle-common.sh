#!/usr/bin/env bash
set -e
set -u

UNAME=$(uname)
ARCH=$(uname -m)
MONGO_VERSION=3.2.15
NODE_VERSION=4.8.4
NPM_VERSION=4.6.1

if [ "$UNAME" == "Linux" ] ; then
    OS="linux"
    stripBinary() {
        strip --remove-section=.comment --remove-section=.note $1
    }
fi

PLATFORM="${UNAME}_${ARCH}"
if [ "$UNAME" == "Linux" ]
then
    if [ "$ARCH" == "i686" ]
    then
        NODE_TGZ="node-v${NODE_VERSION}-linux-x86.tar.gz"
    elif [ "$ARCH" == "x86_64" ]
    then
        NODE_TGZ="node-v${NODE_VERSION}-linux-x64.tar.gz"
    fi
fi

SCRIPTS_DIR=$(dirname $0)
cd "$SCRIPTS_DIR/.."
CHECKOUT_DIR=$(pwd)

DIR=$(mktemp -d -t generate-dev-bundle-XXXXXXXX)
trap 'rm -rf "$DIR" >/dev/null 2>&1' 0

cd "$DIR"
chmod 755 .
umask 022
mkdir build
cd build
