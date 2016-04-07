module tests.realistic_build;

import reggae;

enum fooObj = Target("foo.o", "dmd -c -offoo.o foo.d", [Target("foo.d")]);
enum barObj = Target("bar.o", "dmd -c -ofbar.o bar.d", [Target("bar.d")]);

mixin build!(Target("leapp",
                    "dmd -ofleapp foo.o bar.o",
                    [fooObj, barObj]));
