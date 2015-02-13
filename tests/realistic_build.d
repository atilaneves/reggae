module tests.realistic_build;

import reggae;

const fooObj = Target("foo.o", "dmd -c -offoo.o foo.d", [Target("foo.d")]);
const barObj = Target("bar.o", "dmd -c -ofbar.o bar.d", [Target("bar.d")]);

const build = Build(Target("leapp",
                           "dmd -ofleapp foo.o bar.o",
                           [fooObj, barObj]));
