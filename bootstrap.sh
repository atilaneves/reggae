#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname)" == "Darwin" ]] ; then
    NUM_PROC=$(sysctl -n hw.ncpu)
else
    NUM_PROC=$(nproc)
fi

#1st parameter is the backend to use (e.g. make, ninja)
BACKEND=${1:-make}

DC="${DC:-dmd}"

rm -rf bin

echo "Compiling reggae with dub"
dub build --compiler="$DC"

cd bin || exit 1

echo "Running bootstrapped reggae with backend $BACKEND"
./reggae -b "$BACKEND" --dc="$DC" ..
$BACKEND -j"$NUM_PROC"
