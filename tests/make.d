module tests.make;

import unit_threaded;
import reggae;


void testMakefileNoPath() {
    const build = Build(Target("leapp",
                               "dmd -ofleapp objs/leapp.objs/foo.o objs/leapp.objs/bar.o",
                               [Target("foo.o", "dmd -c -ofobjs/leapp.objs/foo.o foo.d", [Target("foo.d")]),
                                Target("bar.o", "dmd -c -ofobjs/leapp.objs/bar.o bar.d", [Target("bar.d")])],
                            ));
    auto backend = Makefile(build);
    backend.fileName.shouldEqual("Makefile");
    backend.output.shouldEqual(
        "all: leapp\n"
        "objs/leapp.objs/foo.o: foo.d\n"
        "\tdmd -c -ofobjs/leapp.objs/foo.o foo.d\n"
        "objs/leapp.objs/bar.o: bar.d\n"
        "\tdmd -c -ofobjs/leapp.objs/bar.o bar.d\n"
        "leapp: objs/leapp.objs/foo.o objs/leapp.objs/bar.o\n"
        "\tdmd -ofleapp objs/leapp.objs/foo.o objs/leapp.objs/bar.o\n"
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
        "objs/otherapp.objs/boo.o: /global/path/to/boo.c\n"
        "\tgcc -c -o objs/otherapp.objs/boo.o /global/path/to/boo.c\n"
        "objs/otherapp.objs/baz.o: /global/path/to/baz.c\n"
        "\tgcc -c -o objs/otherapp.objs/baz.o /global/path/to/baz.c\n"
        "otherapp: objs/otherapp.objs/boo.o objs/otherapp.objs/baz.o\n"
        "\tgcc -o otherapp objs/otherapp.objs/boo.o objs/otherapp.objs/baz.o\n"
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
