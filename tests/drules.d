module tests.drules;


import reggae;
import reggae.options;
import unit_threaded;
import std.algorithm;


void testDCompileNoIncludePathsNinja() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.d")));
    auto ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["DEPFILE = path/to/src/foo.o.dep"])]);
}


void testDCompileIncludePathsNinja() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    auto ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = -O",
                     "DEPFILE = path/to/src/foo.o.dep"])]);
}

void testDCompileIncludePathsMake() {
    import reggae.config: options;

    auto build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    build.targets.array[0].shellCommand(options.withProjectPath("/tmp/myproject")).shouldEqual(".reggae/dcompile --objFile=path/to/src/foo.o --depFile=path/to/src/foo.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d");
}


void testDLinkNinja() {
    auto build = Build(link(ExeName("bin/lefoo"), [Target("leobj.o")], Flags("-lib")));
    auto ninja = Ninja(build, "/dir/stuff");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build bin/lefoo: _ulink /dir/stuff/leobj.o",
                    ["flags = -lib"])]);
}

void testDCompileWithMultipleFilesMake() {
    import reggae.config: options;

    auto build = Build(dlangPackageObjectFilesPerPackage(
                            ["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                            "-O", ["path/to/src", "other/path"]));

    auto commands = build.targets.map!(a => a.shellCommand(options.withProjectPath("/tmp/myproject"))).array;

    commands.shouldBeSameSetAs(
        [
            ".reggae/dcompile --objFile=other.o --depFile=other.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/other/weird.d",
            ".reggae/dcompile --objFile=path/to/src.o --depFile=path/to/src.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d"]);
}

void testDCompileWithMultipleFilesNinja() {
    auto build = Build(dlangPackageObjectFilesPerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                                              "-O", ["path/to/src", "other/path"]));
    auto ninja = Ninja(build, "/tmp/myproject"); //can't be const because of `sort` below
    NinjaEntry[] entries;

    ninja.buildEntries.shouldBeSameSetAs(
        [

            NinjaEntry("build other.o: _dcompile /tmp/myproject/other/weird.d",
                       ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                        "flags = -O",
                        "DEPFILE = path/to/src/foo.o.dep"]),

            NinjaEntry("build path/to/src.o: _dcompile /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d",
                       ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                        "flags = -O",
                        "DEPFILE = path/to/src/foo.o.dep"]),

            ]);
}


void testLink() {
    import reggae.config: options;
    auto objTarget = link(ExeName("myapp"), [Target("foo.o"), Target("bar.o")], Flags("-L-L"));
    objTarget.shellCommand(options.withProjectPath("/path/to")).shouldEqual("dmd -ofmyapp -L-L /path/to/foo.o /path/to/bar.o");

    auto cppTarget = link(ExeName("cppapp"), [Target("foo.o", "", Target("foo.cpp"))], Flags("--sillyflag"));
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    cppTarget.shellCommand(options.withProjectPath("/foo/bar")).shouldEqual("g++ -o cppapp --sillyflag foo.o");

    auto cTarget = link(ExeName("capp"), [Target("bar.o", "", Target("bar.c"))]);
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    cTarget.shellCommand(options.withProjectPath("/foo/bar")).shouldEqual("gcc -o capp  bar.o");
}


void testObjectFilesEmpty() {
    dlangPackageObjectFilesPerPackage([]).shouldEqual([]);
    dlangPackageObjectFilesPerModule([]).shouldEqual([]);
}
