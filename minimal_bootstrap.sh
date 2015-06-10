# could also use rdmd like this:
# rdmd --build-only -version=reggaelib -version=minimal -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae reggaefile.d -b binary .
# This script doesn't just so it doesn't have to depend on rdmd being available

dmd -version=minimal -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/{reggae_main,options,reggae}.d payload/reggae/{types,build,config}.d payload/reggae/rules/{common,defaults}.d

cd bin
./reggae -b binary ..
./build
