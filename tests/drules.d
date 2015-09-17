module tests.drules;


import reggae;
import unit_threaded;
import std.algorithm;


void testDCompileNoIncludePathsNinja() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.d")));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["DEPFILE = path/to/src/foo.o.dep"])]);
}


void testDCompileIncludePathsNinja() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    const ninja = Ninja(build, "/tmp/myproject");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build path/to/src/foo.o: _dcompile /tmp/myproject/path/to/src/foo.d",
                    ["includes = -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path",
                     "flags = -O",
                     "DEPFILE = path/to/src/foo.o.dep"])]);
}

void testDCompileIncludePathsMake() {
    const build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    build.targets.array[0].shellCommand("/tmp/myproject").shouldEqual(".reggae/dcompile --objFile=path/to/src/foo.o --depFile=path/to/src/foo.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d");
}


void testDLinkNinja() {
    const build = Build(link(ExeName("bin/lefoo"), [Target("leobj.o")], Flags("-lib")));
    const ninja = Ninja(build, "/dir/stuff");
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build bin/lefoo: _ulink /dir/stuff/leobj.o",
                    ["flags = -lib"])]);
}

void testDCompileWithMultipleFilesMake() {
    const build = Build(dlangPackageObjectFilesPerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                                              "-O", ["path/to/src", "other/path"]));
    build.targets.map!(a => a.shellCommand("/tmp/myproject")).shouldBeSameSetAs(
        [".reggae/dcompile --objFile=other.o --depFile=other.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/other/weird.d",
         ".reggae/dcompile --objFile=path/to/src.o --depFile=path/to/src.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d /tmp/myproject/path/to/src/bar.d"
            ]
        );
}

void testDCompileWithMultipleFilesNinja() {
    const build = Build(dlangPackageObjectFilesPerPackage(["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
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
    const objTarget = link(ExeName("myapp"), [Target("foo.o"), Target("bar.o")], Flags("-L-L"));
    objTarget.shellCommand("/path/to").shouldEqual("dmd -ofmyapp -L-L /path/to/foo.o /path/to/bar.o");

    const cppTarget = link(ExeName("cppapp"), [Target("foo.o", "", Target("foo.cpp"))], Flags("--sillyflag"));
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    cppTarget.shellCommand("/foo/bar").shouldEqual("g++ -o cppapp --sillyflag foo.o");

    const cTarget = link(ExeName("capp"), [Target("bar.o", "", Target("bar.c"))]);
    //since foo.o is not a leaf target, the path should not appear (it's created in the build dir)
    cTarget.shellCommand("/foo/bar").shouldEqual("gcc -o capp  bar.o");
}


void testObjectFilesEmpty() {
    dlangPackageObjectFilesPerPackage([]).shouldEqual([]);
    dlangPackageObjectFilesPerModule([]).shouldEqual([]);
}
