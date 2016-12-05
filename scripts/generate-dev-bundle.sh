#!/usr/bin/env bash

set -e
set -u

# Read the bundle version from the meteor shell script.
BUNDLE_VERSION=$(perl -ne 'print $1 if /BUNDLE_VERSION=(\S+)/' meteor)
if [ -z "$BUNDLE_VERSION" ]; then
    echo "BUNDLE_VERSION not found"
    exit 1
fi

source "$(dirname $0)/build-dev-bundle-common.sh"
echo CHECKOUT DIR IS "$CHECKOUT_DIR"
echo BUILDING DEV BUNDLE "$BUNDLE_VERSION" IN "$DIR"

mkdir "${DIR}/bin"
mkdir "${DIR}/etc"
mkdir "${DIR}/build/npm-server-install"
mkdir "${DIR}/build/npm-tool-install"
mkdir -p "${DIR}/server-lib/node_modules"
mkdir -p "${DIR}/lib/node_modules"

#export PATH="$DIR/bin:$PATH"
export HOME="$DIR"
export USERPROFILE="$DIR"

cd "${DIR}/build/npm-server-install"
node "${CHECKOUT_DIR}/scripts/dev-bundle-server-package.js" > package.json
npm install
npm shrinkwrap

cp -R node_modules/* "${DIR}/server-lib/node_modules/"
mv package.json npm-shrinkwrap.json "${DIR}/etc/"

# Fibers ships with compiled versions of its C code for a dozen platforms. This
# bloats our dev bundle. Remove all the ones other than our
# architecture. (Expression based on build.js in fibers source.)
shrink_fibers () {
    FIBERS_ARCH=$(node -p -e 'process.platform + "-" + process.arch + "-" + process.versions.modules')
    mv $FIBERS_ARCH ..
    rm -rf *
    mv ../$FIBERS_ARCH .
}
cd "$DIR/server-lib/node_modules/fibers/bin"
shrink_fibers

cd "${DIR}/build/npm-tool-install"
node "${CHECKOUT_DIR}/scripts/dev-bundle-tool-package.js" > package.json
npm install
cp -R node_modules/* "${DIR}/lib/node_modules/"
cp -R node_modules/.bin "${DIR}/lib/node_modules/"

# Make node-gyp install Node headers and libraries in $DIR/.node-gyp/.
# https://github.com/nodejs/node-gyp/blob/4ee31329e0/lib/node-gyp.js#L52
node "${DIR}/lib/node_modules/node-gyp/bin/node-gyp.js" install
INCLUDE_PATH="${DIR}/.node-gyp/${NODE_VERSION}/include/node"

# Clean up some bulky stuff.
cd "${DIR}/lib/node_modules"
delete () {
    if [ ! -e "$1" ]; then
        echo "Missing (moved?): $1"
        exit 1
    fi
    rm -rf "$1"
}
delete npm/test
delete npm/node_modules/node-gyp
pushd npm/node_modules
ln -s ../../node-gyp ./
popd
delete sqlite3/deps
delete sqlite3/node_modules/nan
delete sqlite3/node_modules/node-pre-gyp
delete wordwrap/test
delete moment/min
# Remove esprima tests to reduce the size of the dev bundle
find . -path '*/esprima-fb/test' | xargs rm -rf

cd "$DIR/lib/node_modules/fibers/bin"
shrink_fibers

cd "$DIR"
echo "${BUNDLE_VERSION}" > .bundle_version.txt
rm -rf build CHANGELOG.md ChangeLog LICENSE README.md
tar czf "${CHECKOUT_DIR}/dev_bundle_${PLATFORM}_${BUNDLE_VERSION}.tar.gz" .
