module tests.build;

import unit_threaded;
import reggae;


void testIsLeaf() {
    Target("tgt").isLeaf.shouldBeTrue;
    Target("other", "", [Target("foo"), Target("bar")]).isLeaf.shouldBeFalse;
    Target("implicits", "", [], [Target("foo")]).isLeaf.shouldBeFalse;
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


void testMultipleOutputs() {
    const target = Target(["foo.hpp", "foo.cpp"], "protocomp $in", [Target("foo.proto")]);
    target.outputs.shouldEqual(["foo.hpp", "foo.cpp"]);
    target.command("myproj").shouldEqual("protocomp myproj/foo.proto");

    const bld = Build(target);
    bld.targets[0].outputs.shouldEqual(["foo.hpp", "foo.cpp"]);
}


void testEnclose() {

    Target("foo.o", "", [Target("foo.c")]).enclose(Target("theapp")).shouldEqual(
            Target("objs/theapp.objs/foo.o", "", [Target("foo.c")]));

    Target("$builddir/bar.o", "", [Target("bar.c")]).enclose(Target("theapp")).shouldEqual(
        Target("bar.o", "", [Target("bar.c")]));

    const leafTarget = Target("foo.c");
    leafTarget.enclose(Target("theapp")).shouldEqual(leafTarget);
}


void testMultipleOutputsImplicits() {
    const protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                             `./compiler $in`,
                             [Target(`protocol.proto`)]);
    const protoObj = Target(`$builddir/bin/protocol.o`,
                            `gcc -o $out -c $builddir/gen/protocol.c`,
                            [], [protoSrcs]);
    const protoD = Target(`$builddir/gen/protocol.d`,
                          `echo "extern(C) " > $out; cat $builddir/gen/protocol.h >> $out`,
                          [], [protoSrcs]);
    const app = Target(`app`,
                       `dmd -of$out $in`,
                       [Target(`src/main.d`), protoObj, protoD]);
    const build = Build(app);

    const newProtoSrcs = Target([`gen/protocol.c`, `gen/protocol.h`],
                                `./compiler $in`,
                                [Target(`protocol.proto`)]);
    const newProtoD = Target(`gen/protocol.d`,
                             `echo "extern(C) " > $out; cat gen/protocol.h >> $out`,
                             [], [newProtoSrcs]);

    build.targets.shouldEqual(
        [Target("app", "dmd -of$out $in",
                [Target("src/main.d"),
                 Target("bin/protocol.o", "gcc -o $out -c gen/protocol.c",
                        [], [newProtoSrcs]),
                 newProtoD])]
        );
}
