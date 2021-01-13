module multiple_outputs.reggaefile_tog;

version(Windows) {
    enum protoObjCmd = `cl.exe /Fo$out -c $builddir/protocol.c`;
    version(DigitalMars)
        enum appCmd = `dmd -m32mscoff -of$out $in`;
    else
        enum appCmd = `dmd -of$out $in`;
} else {
    enum protoObjCmd = `gcc -o $out -c $builddir/protocol.c`;
    enum appCmd = `dmd -of$out $in`;
}

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
