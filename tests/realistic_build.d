module tests.realistic_build;

import reggae;

const build = Build(Target("leapp",
                           [Target("foo.o", [leaf("foo.d")], ["dmd", "-c", "-offoo.o", "foo.d"]),
                            Target("bar.o", [leaf("bar.d")], ["dmd", "-c", "-ofbar.o", "bar.d"])],
                           ["dmd", "-ofleapp", "foo.o", "bar.o"]));
