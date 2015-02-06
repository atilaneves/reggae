module tests.build;

import unit_threaded;
import reggae;


void testMakefileD() {
    const build = Build(Target("leapp",
                               [Target("foo.o", [leaf("foo.d")], ["dmd", "-c", "-offoo.o", "foo.d"]),
                                Target("bar.o", [leaf("bar.d")], ["dmd", "-c", "-ofbar.o", "bar.d"])],
                               ["dmd", "-ofleapp", "foo.o", "bar.o"]));
    auto backend = new Makefile(build);
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


void testMakefileC() {
    const build = Build(Target("otherapp",
                               [Target("boo.o", [leaf("boo.c")], ["gcc", "-c", "-o", "boo.o", "boo.c"]),
                                Target("baz.o", [leaf("baz.c")], ["gcc", "-c", "-o", "baz.o", "baz.c"])],
                               ["gcc", "-o", "otherapp", "boo.o", "baz.o"]));
    auto backend = new Makefile(build);
    backend.fileName.shouldEqual("Makefile");
    backend.output.shouldEqual(
        "all: otherapp\n"
        "boo.o: boo.c\n"
        "\tgcc -c -o boo.o boo.c\n"
        "baz.o: baz.c\n"
        "\tgcc -c -o baz.o baz.c\n"
        "otherapp: boo.o baz.o\n"
        "\tgcc -o otherapp boo.o baz.o\n"
        );
}
