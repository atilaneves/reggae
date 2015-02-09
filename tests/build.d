module tests.build;

import unit_threaded;
import reggae;


void testMakefileNoPath() {
    const build = Build(Target("leapp",
                               [Target("foo.o", [Target("foo.d")], "dmd -c -offoo.o foo.d"),
                                Target("bar.o", [Target("bar.d")], "dmd -c -ofbar.o bar.d")],
                               "dmd -ofleapp foo.o bar.o"));
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


void testMakefilePath() {
    const build = Build(Target("otherapp",
                               [Target("boo.o", [Target("boo.c")], "gcc -c -o $out $in"),
                                Target("baz.o", [Target("baz.c")], "gcc -c -o $out $in")],
                               "gcc -o $out $in"));
    auto backend = new Makefile(build, "/global/path/to/");
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
    Target("other", [Target("foo"), Target("bar")], "").isLeaf.shouldBeFalse;
}


void testInOut() {
    //Tests that specifying $in and $out in the command string gets substituted correctly
    {
        const target = Target("foo",
                              [Target("bar.txt"), Target("baz.txt")],
                              "createfoo -o $out $in");
        target.command.shouldEqual("createfoo -o foo bar.txt baz.txt");
    }
    {
        const target = Target("tgt",
                              [
                                  Target("src1.o", [Target("src1.c")], "gcc -c -o $out $in"),
                                  Target("src2.o", [Target("src2.c")], "gcc -c -o $out $in")
                                  ],
                              "gcc -o $out $in");
        target.command.shouldEqual("gcc -o tgt src1.o src2.o");
    }

    {
        const target = Target(["proto.h", "proto.c"],
                              [Target("proto.idl")],
                              "protocompile $out -i $in");
        target.command.shouldEqual("protocompile proto.h proto.c -i proto.idl");
    }

    {
        const target = Target("lib1.a",
                              [Target(["foo1.o", "foo2.o"], [Target("tmp")], "cmd"),
                               Target("bar.o"),
                               Target("baz.o")],
                              "ar -o$out $in");
        target.command.shouldEqual("ar -olib1.a foo1.o foo2.o bar.o baz.o");
    }
}


void testProject() {
    const target = Target("foo",
                          [Target("bar"), Target("baz")],
                          "makefoo -i $in -o $out -p $project");
    target.command("/tmp").shouldEqual("makefoo -i /tmp/bar /tmp/baz -o foo -p /tmp");
}
