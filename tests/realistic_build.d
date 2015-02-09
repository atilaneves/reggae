module tests.realistic_build;

import reggae;

const fooObj = Target("foo.o", [leaf("foo.d")], "dmd -c -offoo.o foo.d");
const barObj = Target("bar.o", [leaf("bar.d")], "dmd -c -ofbar.o bar.d");

const build = Build(Target("leapp", [fooObj, barObj],
                           "dmd -ofleapp foo.o bar.o"));
