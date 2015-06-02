#1st parameter is the backend to use (e.g. make, ninja)

if [ "$1" != "" ]; then
    BACKEND=$1
else
    BACKEND="make"
fi


#rdmd --compiler=dmd --build-only -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/reggae_main.d

dmd -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/*.d payload/reggae/{dub,rules,config,build,types,sorting,dependencies}.d
cd bin
./reggae -b $BACKEND ..
$BACKEND
