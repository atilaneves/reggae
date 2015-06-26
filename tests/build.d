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
        target.expandCommand.shouldEqual("createfoo -o foo bar.txt baz.txt");
    }
    {
        const target = Target("tgt",
                              "gcc -o $out $in",
                              [
                                  Target("src1.o", "gcc -c -o $out $in", [Target("src1.c")]),
                                  Target("src2.o", "gcc -c -o $out $in", [Target("src2.c")])
                                  ],
            );
        target.expandCommand.shouldEqual("gcc -o tgt src1.o src2.o");
    }

    {
        const target = Target(["proto.h", "proto.c"],
                              "protocompile $out -i $in",
                              [Target("proto.idl")]);
        target.expandCommand.shouldEqual("protocompile proto.h proto.c -i proto.idl");
    }

    {
        const target = Target("lib1.a",
                              "ar -o$out $in",
                              [Target(["foo1.o", "foo2.o"], "cmd", [Target("tmp")]),
                               Target("bar.o"),
                               Target("baz.o")]);
        target.expandCommand.shouldEqual("ar -olib1.a foo1.o foo2.o bar.o baz.o");
    }
}


void testProject() {
    const target = Target("foo",
                          "makefoo -i $in -o $out -p $project",
                          [Target("bar"), Target("baz")]);
    target.expandCommand("/tmp").shouldEqual("makefoo -i /tmp/bar /tmp/baz -o foo -p /tmp");
}


void testMultipleOutputs() {
    const target = Target(["foo.hpp", "foo.cpp"], "protocomp $in", [Target("foo.proto")]);
    target.outputs.shouldEqual(["foo.hpp", "foo.cpp"]);
    target.expandCommand("myproj").shouldEqual("protocomp myproj/foo.proto");

    const bld = Build(target);
    bld.targets.array[0].outputs.shouldEqual(["foo.hpp", "foo.cpp"]);
}


void testInTopLevelObjDir() {

    const theApp = Target("theapp");
    const fooObj = Target("foo.o", "", [Target("foo.c")]);
    fooObj.inTopLevelObjDirOf(theApp).shouldEqual(
        Target("objs/theapp.objs/foo.o", "", [Target("foo.c")]));

    const barObjInBuildDir = Target("$builddir/bar.o", "", [Target("bar.c")]);
    barObjInBuildDir.inTopLevelObjDirOf(theApp).shouldEqual(
        Target("bar.o", "", [Target("bar.c")]));

    const leafTarget = Target("foo.c");
    leafTarget.inTopLevelObjDirOf(theApp).shouldEqual(leafTarget);
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

    build.targets.array.shouldEqual(
        [Target("app", "dmd -of$out $in",
                [Target("src/main.d"),
                 Target("bin/protocol.o", "gcc -o $out -c gen/protocol.c",
                        [], [newProtoSrcs]),
                 newProtoD])]
        );
}


void testRealTargetPath() {
    const fooLib = Target("$project/foo.so", "dmd -of$out $in", [Target("src1.d"), Target("src2.d")]);
    const barLib = Target("$builddir/bar.so", "dmd -of$out $in", [Target("src1.d"), Target("src2.d")]);
    const symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    const symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    const symlinkBar = Target("$builddir/weird/path/thingie2", "ln -sf $in $out", fooLib);

    immutable dirName = "/made/up/dir";

    realTargetPath(dirName, symlink1.outputs[0]).shouldEqual("$project/weird/path/thingie1");
    realTargetPath(dirName, symlink2.outputs[0]).shouldEqual("$project/weird/path/thingie2");
    realTargetPath(dirName, fooLib.outputs[0]).shouldEqual("$project/foo.so");


    realTargetPath(dirName, symlinkBar.outputs[0]).shouldEqual("weird/path/thingie2");
    realTargetPath(dirName, barLib.outputs[0]).shouldEqual("bar.so");

}


void testOptional() {
    enum foo = Target("foo", "dmd -of$out $in", Target("foo.d"));
    enum bar = Target("bar", "dmd -of$out $in", Target("bar.d"));

    optional(bar).target.shouldEqual(bar);
    mixin build!(foo, optional(bar));
    auto build = buildFunc();
    build.targets.array[1].shouldEqual(bar);
}
