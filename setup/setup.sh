#!/bin/bash
FILE=/usr/local/node/bin/node
if [ ! -f "$FILE" ]; then
    echo "$FILE does not exist."
    (MIRROR=https://nodejs.org/dist/latest; VERSION=""; DIR=/usr/local/node; SYSTEM=linux-x64; FILENAME=$(curl -s -L ${MIRROR}${VERSION} | grep 'tar.gz' | grep ${SYSTEM} | cut -d\" -f2); curl -s -L ${MIRROR}${VERSION}/${FILENAME} | tar -xvz --strip-components 1 -C ${DIR})
fi

(PATH=$PATH:/usr/local/node/bin;node setup/setup.js)