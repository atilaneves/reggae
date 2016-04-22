module multiple_outputs.reggaefile_tog;

import reggae;
enum protoSrcs = Target([`$builddir/protocol.c`, `$builddir/protocol.h`],
                        `./compiler $in`,
                        [Target(`protocol.proto`)]);
enum protoObj = Target(`$builddir/protocol.o`,
                       `gcc -o $out -c $builddir/protocol.c`,
                       [], [protoSrcs]);
enum protoD = Target(`$builddir/protocol.d`,
                     `./translator $builddir/protocol.h $out`,
                     [], [protoSrcs]);
enum app = Target(`app`,
                  `dmd -of$out $in`,
                  [Target(`main.d`), protoObj, protoD]);
mixin build!(app);
