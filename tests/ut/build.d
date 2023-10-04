module tests.ut.build;

import unit_threaded;
import reggae;
import reggae.options;
import reggae.path: buildPath;
import std.array;
import std.format;


@("isLeaf") unittest {
    Target("tgt").isLeaf.shouldBeTrue;
    Target("other", "", [Target("foo"), Target("bar")]).isLeaf.shouldBeFalse;
    Target("implicits", "", [], [Target("foo")]).isLeaf.shouldBeFalse;
}


@("$in and $out") unittest {
    import reggae.config: gDefaultOptions;
    //Tests that specifying $in and $out in the command string gets substituted correctly
    {
        auto target = Target("foo",
                              "createfoo -o $out $in",
                              [Target("bar.txt"), Target("baz.txt")]);
        target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
            "createfoo -o foo " ~ buildPath("/path/to/bar.txt") ~ " " ~ buildPath("/path/to/baz.txt"));
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
            "protocompile proto.h proto.c -i " ~ buildPath("/path/to/proto.idl"));
    }

    {
        auto target = Target("lib1.a",
                              "ar -o$out $in",
                              [Target(["foo1.o", "foo2.o"], "cmd", [Target("tmp")]),
                               Target("bar.o"),
                               Target("baz.o")]);
        target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
            "ar -olib1.a foo1.o foo2.o " ~ buildPath("/path/to/bar.o") ~ " " ~ buildPath("/path/to/baz.o"));
    }
}


@("Project") unittest {
    import reggae.config: gDefaultOptions;
    auto target = Target("foo",
                          "makefoo -i $in -o $out -p $project",
                          [Target("bar"), Target("baz")]);
    target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
        "makefoo -i " ~ buildPath("/path/to/bar") ~ " " ~ buildPath("/path/to/baz") ~ " -o foo -p " ~ buildPath("/path/to"));
}


@("Multiple outputs") unittest {
    import reggae.config: gDefaultOptions;
    auto target = Target(["foo.hpp", "foo.cpp"], "protocomp $in", [Target("foo.proto")]);
    target.rawOutputs.shouldEqual(["foo.hpp", "foo.cpp"]);
    target.shellCommand(gDefaultOptions.withProjectPath("myproj")).shouldEqual("protocomp " ~ buildPath("myproj/foo.proto"));

    auto bld = Build(target);
    bld.targets.array[0].rawOutputs.shouldEqual(["foo.hpp", "foo.cpp"]);
}


@("InTopLevelObjDir") unittest {

    auto theApp = Target("theapp");
    auto dirName = objDirOf(theApp);
    auto fooObj = Target("foo.o", "", [Target("foo.c")]);
    fooObj.inTopLevelObjDirOf(dirName).shouldEqual(
        Target(buildPath(".reggae/objs/theapp.objs/foo.o"), "", [Target(buildPath("$project/foo.c"))]));

    auto barObjInBuildDir = Target("$builddir/bar.o", "", [Target(buildPath("$project/bar.c"))]);
    barObjInBuildDir.inTopLevelObjDirOf(dirName).shouldEqual(
        Target("bar.o", "", [Target(buildPath("$project/bar.c"))]));

    auto leafTarget = Target("foo.c");
    leafTarget.inTopLevelObjDirOf(dirName).shouldEqual(Target(buildPath("$project/foo.c")));
}


@("Multiple outputs, implicits") unittest {
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

    auto newProtoSrcs = Target([buildPath("gen/protocol.c"), buildPath("gen/protocol.h")],
                                `./compiler $in`,
                                [Target(buildPath("$project/protocol.proto"))]);
    auto newProtoD = Target(buildPath("gen/protocol.d"),
                             `echo "extern(C) " > $out; cat gen/protocol.h >> $out`,
                             [], [newProtoSrcs]);

    build.targets.array.shouldEqual(
        [Target("app", "dmd -of$out $in",
                [Target(buildPath("$project/src/main.d")),
                 Target(buildPath("bin/protocol.o"), "gcc -o $out -c gen/protocol.c",
                        [], [newProtoSrcs]),
                 newProtoD])]
        );
}


@("optional") unittest {
    enum foo = Target("foo", "dmd -of$out $in", Target("foo.d"));
    enum bar = Target("bar", "dmd -of$out $in", Target("bar.d"));
    enum newBar = Target("bar", "dmd -of$out $in", Target(buildPath("$project/bar.d")));

    optional(bar).target.shouldEqual(newBar);
    auto build = Build(foo, optional(bar));
    build.targets.array[1].shouldEqual(newBar);
}


@("Diamond deps") unittest {
    auto src1 = Target("src1.d");
    auto src2 = Target("src2.d");
    auto obj1 = Target("obj1.o", "dmd -of$out -c $in", src1);
    auto obj2 = Target("obj2.o", "dmd -of$out -c $in", src2);
    auto fooLib = Target("$project/foo.so", "dmd -of$out $in", [obj1, obj2]);
    auto symlink1 = Target("$project/weird/path/thingie1", "ln -sf $in $out", fooLib);
    auto symlink2 = Target("$project/weird/path/thingie2", "ln -sf $in $out", fooLib);
    auto build = Build(symlink1, symlink2);

    auto newSrc1 = Target(buildPath("$project/src1.d"));
    auto newSrc2 = Target(buildPath("$project/src2.d"));
    auto newObj1 = Target(buildPath(".reggae/objs/__project__/foo.so.objs/obj1.o"), "dmd -of$out -c $in", newSrc1);
    auto newObj2 = Target(buildPath(".reggae/objs/__project__/foo.so.objs/obj2.o"), "dmd -of$out -c $in", newSrc2);
    auto newFooLib = Target(buildPath("$project/foo.so"), "dmd -of$out $in", [newObj1, newObj2]);
    auto newSymlink1 = Target(buildPath("$project/weird/path/thingie1"), "ln -sf $in $out", newFooLib);
    auto newSymlink2 = Target(buildPath("$project/weird/path/thingie2"), "ln -sf $in $out", newFooLib);

    build.range.array.shouldEqual([newObj1, newObj2, newFooLib, newSymlink1, newSymlink2]);
}

@("Phobos optional bug") unittest {
    enum obj1 = Target("obj1.o", "dmd -of$out -c $in", Target("src1.d"));
    enum obj2 = Target("obj2.o", "dmd -of$out -c $in", Target("src2.d"));
    enum foo = Target("foo", "dmd -of$out $in", [obj1, obj2]);
    Target bar() {
        return Target("bar", "dmd -of$out $in", [obj1, obj2]);
    }
    auto build = Build(foo, optional!(bar));

    auto fooObj1 = Target(buildPath(".reggae/objs/foo.objs/obj1.o"), "dmd -of$out -c $in", Target(buildPath("$project/src1.d")));
    auto fooObj2 = Target(buildPath(".reggae/objs/foo.objs/obj2.o"), "dmd -of$out -c $in", Target(buildPath("$project/src2.d")));
    auto newFoo = Target("foo", "dmd -of$out $in", [fooObj1, fooObj2]);

    auto barObj1 = Target(buildPath(".reggae/objs/bar.objs/obj1.o"), "dmd -of$out -c $in", Target(buildPath("$project/src1.d")));
    auto barObj2 = Target(buildPath(".reggae/objs/bar.objs/obj2.o"), "dmd -of$out -c $in", Target(buildPath("$project/src2.d")));
    auto newBar = Target("bar", "dmd -of$out $in", [barObj1, barObj2]);

    build.range.array.shouldEqual([fooObj1, fooObj2, newFoo, barObj1, barObj2, newBar]);
}


@("Outputs in project path") unittest {
    auto mkDir = Target("$project/foodir", "mkdir -p $out", [], []);
    mkDir.expandOutputs("/path/to/proj").shouldEqual([buildPath("/path/to/proj/foodir")]);
}


@("expandOutputs") unittest {
    auto foo = Target("$project/foodir", "mkdir -p $out", [], []);
    foo.expandOutputs("/path/to/proj").array.shouldEqual([buildPath("/path/to/proj/foodir")]);

    auto bar = Target("$builddir/foodir", "mkdir -p $out", [], []);
    bar.expandOutputs("/path/to/proj").array.shouldEqual(["foodir"]);
}


@("Command $builddir") unittest {
    import reggae.config: gDefaultOptions;
    auto cmd = Command("dmd -of$builddir/ut_debug $in");
    cmd.shellCommand(gDefaultOptions.withProjectPath("/path/to/proj"), Language.unknown, ["$builddir/ut_debug"], ["foo.d"]).
        shouldEqual("dmd -ofut_debug foo.d");
}


@("$builddir in top-level target") unittest {
    auto ao = objectFile(Options(), SourceFile("a.c"));
    auto liba = Target("$builddir/liba.a", "ar rcs liba.a a.o", [ao]);
    auto build = Build(liba);
    build.targets[0].rawOutputs.shouldEqual(["liba.a"]);
}


@("Output in $builddir") unittest {
    auto target = Target("$builddir/foo/bar", "cmd", [Target("foo.d"), Target("bar.d")]);
    target.expandOutputs("/path/to").shouldEqual([buildPath("foo/bar")]);
}

@("Output in $project") unittest {
    auto target = Target("$project/foo/bar", "cmd", [Target("foo.d"), Target("bar.d")]);
    target.expandOutputs("/path/to").shouldEqual([buildPath("/path/to/foo/bar")]);
}

@("Cmd with $builddir") unittest {
    auto target = Target("output", "cmd -I$builddir/include $in $out", [Target("foo.d"), Target("bar.d")]);
    target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
        "cmd -Iinclude " ~ buildPath("/path/to/foo.d") ~ " " ~ buildPath("/path/to/bar.d") ~ " output");
}

@("Cmd with $project") unittest {
    auto target = Target("output", "cmd -I$project/include $in $out", [Target("foo.d"), Target("bar.d")]);
    target.shellCommand(gDefaultOptions.withProjectPath("/path/to")).shouldEqual(
        "cmd -I" ~ buildPath("/path/to") ~ "/include" ~ " " ~ buildPath("/path/to/foo.d") ~ " " ~ buildPath("/path/to/bar.d") ~ " output");
}

@("Deps in $builddir") unittest {
    auto target = Target("output", "cmd", [Target("$builddir/foo.d"), Target("$builddir/bar.d")]);
    target.dependenciesInProjectPath("/path/to").shouldEqual(["foo.d", "bar.d"]);
}

@("Deps in $project") unittest {
    auto target = Target("output", "cmd", [Target("$project/foo.d"), Target("$project/bar.d")]);
    target.dependenciesInProjectPath("/path/to").shouldEqual(
        [buildPath("/path/to/foo.d"), buildPath("/path/to/bar.d")]);
}


@("Build with one dep in $builddir") unittest {
    auto target = Target("output", "cmd -o $out -c $in", Target("$builddir/input.d"));
    alias top = link!(ExeName("ut"), targetConcat!(target));
    auto build = Build(top);
    build.targets[0].dependencyTargets[0].dependenciesInProjectPath("/path/to").shouldEqual(["input.d"]);
}


@("Replace concrete compiler with variables")
unittest {
    immutable str = "\n" ~
        "clang -o foo -c foo.c\n" ~
        "clang++ -o foo -c foo.cpp\n" ~
        "ldmd -offoo -c foo.d\n";
    auto opts = Options();
    opts.cCompiler = "clang";
    opts.cppCompiler = "clang++";
    opts.dCompiler = "ldmd";
    str.replaceConcreteCompilersWithVars(opts).shouldEqual(
        "\n" ~
        "$(CC) -o foo -c foo.c\n" ~
        "$(CXX) -o foo -c foo.cpp\n" ~
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
                Target(buildPath(".reggae/objs/output.objs/med"),
                       "medcmd -o $out $in",
                       buildPath("$project/input")))]);
}

@("input path with environment variable")
unittest {
    auto build = Build(Target("app", "dmd -of$out $in", [Target("foo.d"), Target("$LIB/liblua.a")]));
    Options options;
    options.projectPath = "/proj";

    const srcFile = buildPath("/proj/foo.d");
    const libFile = buildPath("$LIB/liblua.a");
    build.targets[0].shellCommand(options).shouldEqual(
        "dmd -ofapp %s %s".format(srcFile, libFile));
    build.targets[0].dependenciesInProjectPath(options.projectPath)
        .shouldEqual([srcFile, libFile]);
}
