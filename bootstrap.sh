#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname)" == "Darwin" ]] ; then
    NUM_PROC=$(sysctl -n hw.ncpu)
else
    NUM_PROC=$(nproc)
fi

#1st parameter is the backend to use (e.g. make, ninja)

if [ "$#" -ne 1 ]; then
    echo "Error: Must pass in backend (make, ninja)"
    exit 1
fi

BACKEND=$1

DC="${DC:-dmd}"

rm -rf bin

echo "Compiling reggae"
dub build --compiler="$DC"

cd bin || exit 1
echo "Running boostrapped reggae with backend $BACKEND"
./reggae -b $BACKEND --dc="$DC" ..
$BACKEND -j"$NUM_PROC"
