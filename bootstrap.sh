#1st parameter is the backend to use (e.g. make, ninja)

if [ "$1" != "" ]; then
    BACKEND=$1
else
    BACKEND="make"
fi


dmd -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/*.d src/reggae/dub/*.d payload/reggae/backend/*.d payload/reggae/{reflect,dub_info,config,build,types,sorting,dependencies,range}.d payload/reggae/rules/*.d payload/reggae/core/*.d payload/reggae/core/rules/*.d
cd bin
./reggae -b $BACKEND ..
$BACKEND
