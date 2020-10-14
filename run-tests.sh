#!/usr/bin/env bash

set -euo pipefail

# the Travis CI machines don't like tup
# installing the right ruby version in travis for D projects is a pain

if [ "$DC" == "dmd" ] && [ -n "$TRAVIS" ]; then
    bin/ut ~@tup ~@travis_oops;
    cucumber --tags ~@tup --tags ~@ruby --tags ~@lua;
else
    dub test --build=unittest-cov --compiler="$DC"
fi
