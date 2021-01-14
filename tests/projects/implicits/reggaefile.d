module implicits.reggaefile;

import reggae;
enum mainObj = Target(`main` ~ objExt,
                      `dmd -c -J$project -of$out $in`,
                      [Target(`main.d`)],
                      [Target(`string.txt`)]);
mixin build!(Target(`leapp`, `dmd -of$out $in`, mainObj));
