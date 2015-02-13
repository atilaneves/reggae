module tests.build;

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

void testIsLeaf() {
    Target("tgt").isLeaf.shouldBeTrue;
    Target("other", "", [Target("foo"), Target("bar")]).isLeaf.shouldBeFalse;
}


void testInOut() {
    //Tests that specifying $in and $out in the command string gets substituted correctly
    {
        const target = Target("foo",
                              "createfoo -o $out $in",
                              [Target("bar.txt"), Target("baz.txt")]);
        target.command.shouldEqual("createfoo -o foo bar.txt baz.txt");
    }
    {
        const target = Target("tgt",
                              "gcc -o $out $in",
                              [
                                  Target("src1.o", "gcc -c -o $out $in", [Target("src1.c")]),
                                  Target("src2.o", "gcc -c -o $out $in", [Target("src2.c")])
                                  ],
);
        target.command.shouldEqual("gcc -o tgt src1.o src2.o");
    }

    {
        const target = Target(["proto.h", "proto.c"],
                              "protocompile $out -i $in",
                              [Target("proto.idl")]);
        target.command.shouldEqual("protocompile proto.h proto.c -i proto.idl");
    }

    {
        const target = Target("lib1.a",
                              "ar -o$out $in",
                              [Target(["foo1.o", "foo2.o"], "cmd", [Target("tmp")]),
                               Target("bar.o"),
                               Target("baz.o")]);
        target.command.shouldEqual("ar -olib1.a foo1.o foo2.o bar.o baz.o");
    }
}


void testProject() {
    const target = Target("foo",
                          "makefoo -i $in -o $out -p $project",
                          [Target("bar"), Target("baz")]);
    target.command("/tmp").shouldEqual("makefoo -i /tmp/bar /tmp/baz -o foo -p /tmp");
}
