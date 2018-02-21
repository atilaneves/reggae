#!/usr/bin/env bash

set -euo pipefail

#1st parameter is the backend to use (e.g. make, ninja)

if [ "$#" -ne 1 ]; then
    echo "Error: Must pass in backend (make, ninja)"
    exit 1
fi

BACKEND=$1

COMP=${DMD:="dmd"}

rm -rf bin

echo "Compiling reggae"
$COMP -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/*.d src/reggae/dub/*.d payload/reggae/backend/*.d payload/reggae/{options,reflect,config,build,types,sorting,dependencies,range,buildgen,package,ctaa,file,path}.d payload/reggae/rules/*.d payload/reggae/core/*.d payload/reggae/core/rules/*.d payload/reggae/dub/info.d

cd bin || exit 1
echo "Running boostrapped reggae with backend $BACKEND"
./reggae -b $BACKEND --dc=$DMD ..
$BACKEND -j`nproc`
