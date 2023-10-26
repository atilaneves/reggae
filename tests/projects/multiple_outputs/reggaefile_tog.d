module multiple_outputs.reggaefile_tog;

// Check out the CI configuration: dmd on Windows uses 32-bit
version(Windows)
    version(DigitalMars)
        enum is32bitBuild = true;


static if(is(typeof(is32bitBuild)))
    enum arch = ` -m32`;
else
    enum arch = ``;

enum appCmd = `dmd` ~ arch ~ ` -of$out $in`;

version(Windows)
    enum protoObjCmd = `cl.exe /Fo$out -c $builddir/protocol.d`;
 else
    enum protoObjCmd = `gcc -o $out -c $builddir/protocol.c`;


import reggae;
import reggae.path: buildPath;

enum protoSrcs = Target([`$builddir/protocol.c`, `$builddir/protocol.h`],
                        buildPath(`./compiler`) ~ ` $in`,
                        [Target(`protocol.proto`)]);
enum protoObj = Target(`$builddir/protocol` ~ objExt,
                       protoObjCmd,
                       [], [protoSrcs]);
enum protoD = Target(`$builddir/protocol.d`,
                     buildPath(`./translator`) ~ ` $builddir/protocol.h $out`,
                     [], [protoSrcs]);
enum app = Target(`app`,
                  appCmd,
                  [Target(`main.d`), protoObj, protoD]);
mixin build!(app);
