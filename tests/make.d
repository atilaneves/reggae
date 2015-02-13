module tests.make;

import unit_threaded;
import reggae;


void testMakefileNoPath() {
    const build = Build(Target("leapp",
                               "dmd -ofleapp foo.o bar.o",
                               [Target("foo.o", "dmd -c -offoo.o foo.d", [Target("foo.d")]),
                                Target("bar.o", "dmd -c -ofbar.o bar.d", [Target("bar.d")])],
                            ));
    auto backend = Makefile(build);
    backend.fileName.shouldEqual("Makefile");
    backend.output.shouldEqual(
        "all: leapp\n"
        "foo.o: foo.d\n"
        "\tdmd -c -offoo.o foo.d\n"
        "bar.o: bar.d\n"
        "\tdmd -c -ofbar.o bar.d\n"
        "leapp: foo.o bar.o\n"
        "\tdmd -ofleapp foo.o bar.o\n"
        );
}


void testMakefilePath() {
    const build = Build(Target("otherapp",
                               "gcc -o $out $in",
                               [Target("boo.o", "gcc -c -o $out $in", [Target("boo.c")]),
                                Target("baz.o", "gcc -c -o $out $in", [Target("baz.c")])],
                            ));
    auto backend = Makefile(build, "/global/path/to/");
    backend.fileName.shouldEqual("Makefile");
    backend.output.shouldEqual(
        "all: otherapp\n"
        "boo.o: /global/path/to/boo.c\n"
        "\tgcc -c -o boo.o /global/path/to/boo.c\n"
        "baz.o: /global/path/to/baz.c\n"
        "\tgcc -c -o baz.o /global/path/to/baz.c\n"
        "otherapp: boo.o baz.o\n"
        "\tgcc -o otherapp boo.o baz.o\n"
        );
}


void testImplicitDependencies() {
    const target = Target("foo.o", "gcc -o $out -c $in", [Target("foo.c")], [Target("foo.h")]);
    const make = Makefile(Build(target));
    make.output.shouldEqual(
        "all: foo.o\n"
        "foo.o: foo.c foo.h\n"
        "\tgcc -o foo.o -c foo.c\n"
        );
}
