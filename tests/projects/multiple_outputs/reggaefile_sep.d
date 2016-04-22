module multiple_outputs.reggaefile_sep;

import reggae;
enum protoC = Target(`$builddir/protocol.c`,
                     `./compiler $in`,
                     [Target(`protocol.proto`)]);
enum protoH = Target(`$builddir/protocol.h`,
                     `./compiler $in`,
                     [Target(`protocol.proto`)]);
enum protoObj = Target(`$builddir/protocol.o`,
                       `gcc -o $out -c $in`,
                       [protoC]);
enum protoD = Target(`$builddir/protocol.d`,
                     `./translator $in $out`,
                     [protoH]);
enum app = Target(`app`,
                  `dmd -of$out $in`,
                  [Target(`main.d`), protoObj, protoD]);
mixin build!(app);
