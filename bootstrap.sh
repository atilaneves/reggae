#1st parameter is the backend to use (e.g. make, ninja)

if [ "$1" != "" ]; then
    BACKEND=$1
else
    BACKEND="make"
fi

rm -rf bin

dmd -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/*.d src/reggae/dub/*.d payload/reggae/backend/*.d payload/reggae/{reflect,config,build,types,sorting,dependencies,range,buildgen,package,ctaa}.d payload/reggae/rules/*.d payload/reggae/core/*.d payload/reggae/core/rules/*.d payload/reggae/dub/info.d
cd bin
./reggae -b $BACKEND ..
$BACKEND
