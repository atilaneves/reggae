module multiple_outputs.reggaefile_sep;

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
    enum protoObjCmd = `cl.exe /Fo$out -c $in`;
 else
    enum protoObjCmd = `gcc -o $out -c $in`;


import reggae;
import reggae.path: buildPath;

enum protoC = Target(`$builddir/protocol.c`,
                     buildPath(`./compiler`) ~ ` $in`,
                     [Target(`protocol.proto`)]);
enum protoH = Target(`$builddir/protocol.h`,
                     buildPath(`./compiler`) ~ ` $in`,
                     [Target(`protocol.proto`)]);
enum protoObj = Target(`$builddir/protocol` ~ objExt,
                       protoObjCmd,
                       [protoC]);
enum protoD = Target(`$builddir/protocol.d`,
                     buildPath(`./translator`) ~ ` $in $out`,
                     [protoH]);
enum app = Target(`app`,
                  appCmd,
                  [Target(`main.d`), protoObj, protoD]);
mixin build!(app);
