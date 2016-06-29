module tests.ut.build;

import unit_threaded;
import reggae;
import reggae.options;
import std.array;


void testIsLeaf() {
    Target("tgt").isLeaf.shouldBeTrue;
    Target("other", "", [Target("foo"), Target("bar")]).isLeaf.shouldBeFalse;
    Target("implicits", "", [], [Target("foo")]).isLeaf.shouldBeFalse;
}


void testInOut() {
    import reggae.config: gDefaultOptions;
    //Tests that specifying $in and $out in the command string gets substituted correctly
    {
        auto target = Target("foo",
                              "createfoo -o $out $in",
                              [Target("bar.txt"), Target("baz.txt")]);
        target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
            "createfoo -o foo /path/to/bar.txt /path/to/baz.txt");
    }
    {
        auto target = Target("tgt",
                              "gcc -o $out $in",
                              [
                                  Target("src1.o", "gcc -c -o $out $in", [Target("src1.c")]),
                                  Target("src2.o", "gcc -c -o $out $in", [Target("src2.c")])
                                  ],
            );
        target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual("gcc -o tgt src1.o src2.o");
    }

    {
        auto target = Target(["proto.h", "proto.c"],
                              "protocompile $out -i $in",
                              [Target("proto.idl")]);
        target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
            "protocompile proto.h proto.c -i /path/to/proto.idl");
    }

    {
        auto target = Target("lib1.a",
                              "ar -o$out $in",
                              [Target(["foo1.o", "foo2.o"], "cmd", [Target("tmp")]),
                               Target("bar.o"),
                               Target("baz.o")]);
        target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
            "ar -olib1.a foo1.o foo2.o /path/to/bar.o /path/to/baz.o");
    }
}


void testProject() {
    import reggae.config: gDefaultOptions;
    auto target = Target("foo",
                          "makefoo -i $in -o $out -p $project",
                          [Target("bar"), Target("baz")]);
    target.shellCommand(gDefaultOptions.withProjectPath("/tmp")).shouldEqual("makefoo -i /tmp/bar /tmp/baz -o foo -p /tmp");
}


void testMultipleOutputs() {
    import reggae.config: gDefaultOptions;
    auto target = Target(["foo.hpp", "foo.cpp"], "protocomp $in", [Target("foo.proto")]);
    target.rawOutputs.shouldEqual(["foo.hpp", "foo.cpp"]);
    target.shellCommand(gDefaultOptions.withProjectPath("myproj")).shouldEqual("protocomp myproj/foo.proto");

    auto bld = Build(target);
    bld.targets.array[0].rawOutputs.shouldEqual(["foo.hpp", "foo.cpp"]);
}


void testInTopLevelObjDir() {

    auto theApp = Target("theapp");
    auto dirName = topLevelDirName(theApp);
    auto fooObj = Target("foo.o", "", [Target("foo.c")]);
    fooObj.inTopLevelObjDirOf(dirName).shouldEqual(
        Target("objs/theapp.objs/foo.o", "", [Target("foo.c")]));

    auto barObjInBuildDir = Target("$builddir/bar.o", "", [Target("bar.c")]);
    barObjInBuildDir.inTopLevelObjDirOf(dirName).shouldEqual(
        Target("bar.o", "", [Target("bar.c")]));

    auto leafTarget = Target("foo.c");
    leafTarget.inTopLevelObjDirOf(dirName).shouldEqual(leafTarget);
}


void testMultipleOutputsImplicits() {
    auto protoSrcs = Target([`$builddir/gen/protocol.c`, `$builddir/gen/protocol.h`],
                             `./compiler $in`,
                             [Target(`protocol.proto`)]);
    auto protoObj = Target(`$builddir/bin/protocol.o`,
                            `gcc -o $out -c $builddir/gen/protocol.c`,
                            [], [protoSrcs]);
    auto protoD = Target(`$builddir/gen/protocol.d`,
                          `echo "extern(C) " > $out; cat $builddir/gen/protocol.h >> $out`,
                          [], [protoSrcs]);
    auto app = Target(`app`,
                       `dmd -of$out $in`,
                       [Target(`src/main.d`), protoObj, protoD]);
    auto build = Build(app);

    auto newProtoSrcs = Target([`gen/protocol.c`, `gen/protocol.h`],
                                `./compiler $in`,
                                [Target(`protocol.proto`)]);
    auto newProtoD = Target(`gen/protocol.d`,
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
    auto fooLib = Target("$project/foo.so", "dmd -of$out $in", [Target("src1.d"), Target("src2.d")]);
    auto barLib = Target("$builddir/bar.so", "dmd -of$out $in", [Target("src1.d"), Target("src2.d")]);
    auto symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    auto symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    auto symlinkBar = Target("$builddir/weird/path/thingie2", "ln -sf $in $out", fooLib);

    immutable dirName = "/made/up/dir";

    realTargetPath(dirName, symlink1.rawOutputs[0]).shouldEqual("$project/weird/path/thingie1");
    realTargetPath(dirName, symlink2.rawOutputs[0]).shouldEqual("$project/weird/path/thingie2");
    realTargetPath(dirName, fooLib.rawOutputs[0]).shouldEqual("$project/foo.so");


    realTargetPath(dirName, symlinkBar.rawOutputs[0]).shouldEqual("weird/path/thingie2");
    realTargetPath(dirName, barLib.rawOutputs[0]).shouldEqual("bar.so");

}


void testOptional() {
    enum foo = Target("foo", "dmd -of$out $in", Target("foo.d"));
    enum bar = Target("bar", "dmd -of$out $in", Target("bar.d"));

    optional(bar).target.shouldEqual(bar);
    mixin build!(foo, optional(bar));
    auto build = buildFunc();
    build.targets.array[1].shouldEqual(bar);
}


void testDiamondDeps() {
    auto src1 = Target("src1.d");
    auto src2 = Target("src2.d");
    auto obj1 = Target("obj1.o", "dmd -of$out -c $in", src1);
    auto obj2 = Target("obj2.o", "dmd -of$out -c $in", src2);
    auto fooLib = Target("$project/foo.so", "dmd -of$out $in", [obj1, obj2]);
    auto symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    auto symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    auto build = Build(symlink1, symlink2);

    auto newObj1 = Target("objs/$project/foo.so.objs/obj1.o", "dmd -of$out -c $in", src1);
    auto newObj2 = Target("objs/$project/foo.so.objs/obj2.o", "dmd -of$out -c $in", src2);
    auto newFooLib = Target("$project/foo.so", "dmd -of$out $in", [newObj1, newObj2]);
    auto newSymlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", newFooLib);
    auto newSymlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", newFooLib);

    build.range.array.shouldEqual([newObj1, newObj2, newFooLib, newSymlink1, newSymlink2]);
}

void testPhobosOptionalBug() {
    enum obj1 = Target("obj1.o", "dmd -of$out -c $in", Target("src1.d"));
    enum obj2 = Target("obj2.o", "dmd -of$out -c $in", Target("src2.d"));
    enum foo = Target("foo", "dmd -of$out $in", [obj1, obj2]);
    Target bar() {
        return Target("bar", "dmd -of$out $in", [obj1, obj2]);
    }
    mixin build!(foo, optional!(bar));
    auto build = buildFunc();

    auto fooObj1 = Target("objs/foo.objs/obj1.o", "dmd -of$out -c $in", Target("src1.d"));
    auto fooObj2 = Target("objs/foo.objs/obj2.o", "dmd -of$out -c $in", Target("src2.d"));
    auto newFoo = Target("foo", "dmd -of$out $in", [fooObj1, fooObj2]);

    auto barObj1 = Target("objs/bar.objs/obj1.o", "dmd -of$out -c $in", Target("src1.d"));
    auto barObj2 = Target("objs/bar.objs/obj2.o", "dmd -of$out -c $in", Target("src2.d"));
    auto newBar = Target("bar", "dmd -of$out $in", [barObj1, barObj2]);

    build.range.array.shouldEqual([fooObj1, fooObj2, newFoo, barObj1, barObj2, newBar]);
}


void testOutputsInProjectPath() {
    auto mkDir = Target("$project/foodir", "mkdir -p $out", [], []);
    mkDir.expandOutputs("/path/to/proj").shouldEqual(["/path/to/proj/foodir"]);
}


void testExpandOutputs() {
    auto foo = Target("$project/foodir", "mkdir -p $out", [], []);
    foo.expandOutputs("/path/to/proj").array.shouldEqual(["/path/to/proj/foodir"]);

    auto bar = Target("$builddir/foodir", "mkdir -p $out", [], []);
    bar.expandOutputs("/path/to/proj").array.shouldEqual(["foodir"]);
}


void testCommandBuilddir() {
    import reggae.config: gDefaultOptions;
    auto cmd = Command("dmd -of$builddir/ut_debug $in");
    cmd.shellCommand(gDefaultOptions.withProjectPath("/path/to/proj"), Language.unknown, ["$builddir/ut_debug"], ["foo.d"]).
        shouldEqual("dmd -ofut_debug foo.d");
}


void testBuilddirInTopLevelTarget() {
    auto ao = objectFile(SourceFile("a.c"));
    auto liba = Target("$builddir/liba.a", "ar rcs liba.a a.o", [ao]);
    mixin build!(liba);
    auto build = buildFunc();
    build.targets[0].rawOutputs.shouldEqual(["liba.a"]);
}


void testOutputInBuildDir() {
    auto target = Target("$builddir/foo/bar", "cmd", [Target("foo.d"), Target("bar.d")]);
    target.expandOutputs("/path/to").shouldEqual(["foo/bar"]);
}

void testOutputInProjectDir() {
    auto target = Target("$project/foo/bar", "cmd", [Target("foo.d"), Target("bar.d")]);
    target.expandOutputs("/path/to").shouldEqual(["/path/to/foo/bar"]);
}

void testCmdInBuildDir() {
    auto target = Target("output", "cmd -I$builddir/include $in $out", [Target("foo.d"), Target("bar.d")]);
    target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual("cmd -Iinclude /path/to/foo.d /path/to/bar.d output");
}

void testCmdInProjectDir() {
    auto target = Target("output", "cmd -I$project/include $in $out", [Target("foo.d"), Target("bar.d")]);
    target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual("cmd -I/path/to/include /path/to/foo.d /path/to/bar.d output");
}

void testDepsInBuildDir() {
    auto target = Target("output", "cmd", [Target("$builddir/foo.d"), Target("$builddir/bar.d")]);
    target.dependenciesInProjectPath("/path/to").shouldEqual(["foo.d", "bar.d"]);
}

void testDepsInProjectDir() {
    auto target = Target("output", "cmd", [Target("$project/foo.d"), Target("$project/bar.d")]);
    target.dependenciesInProjectPath("/path/to").shouldEqual(["/path/to/foo.d", "/path/to/bar.d"]);
}


void testBuildWithOneDepInBuildDir() {
    auto target = Target("output", "cmd -o $out -c $in", Target("$builddir/input.d"));
    alias top = link!(ExeName("ut"), targetConcat!(target));
    auto build = Build(top);
    build.targets[0].dependencyTargets[0].dependenciesInProjectPath("/path/to").shouldEqual(["input.d"]);
}


@("Replace concrete compiler with variables")
unittest {
    immutable str = "\n"
        "clang -o foo -c foo.c\n"
        "clang++ -o foo -c foo.cpp\n"
        "ldmd -offoo -c foo.d\n";
    auto opts = Options();
    opts.cCompiler = "clang";
    opts.cppCompiler = "clang++";
    opts.dCompiler = "ldmd";
    str.replaceConcreteCompilersWithVars(opts).shouldEqual(
        "\n"
        "$(CC) -o foo -c foo.c\n"
        "$(CXX) -o foo -c foo.cpp\n"
        "$(DC) -offoo -c foo.d\n"
        );
}


@("optional targets should also sandbox their dependencies") unittest {
    auto med = Target("med", "medcmd -o $out $in", Target("input"));
    auto tgt = Target("output", "cmd -o $out $in", med);
    auto build = Build(optional(tgt));
    build.targets.shouldEqual(
        [Target("output",
                "cmd -o $out $in",
                Target("objs/output.objs/med",
                       "medcmd -o $out $in",
                       "input"))]);
}
