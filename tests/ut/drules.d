module tests.ut.drules;


import reggae;
import reggae.options;
import unit_threaded;
import std.algorithm;
import std.array;


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
    import reggae.config: gDefaultOptions;

    auto build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    build.targets.array[0].shellCommand(gDefaultOptions.withProjectPath("/tmp/myproject")).shouldEqual(".reggae/dcompile --objFile=path/to/src/foo.o --depFile=path/to/src/foo.o.dep dmd -O -I/tmp/myproject/path/to/src -I/tmp/myproject/other/path  /tmp/myproject/path/to/src/foo.d");
}


void testDCompileWithMultipleFilesMake() {
    import reggae.config: gDefaultOptions;

    auto build = Build(dlangPackageObjectFilesPerPackage(
                            ["path/to/src/foo.d", "path/to/src/bar.d", "other/weird.d"],
                            "-O", ["path/to/src", "other/path"]));

    auto commands = build.targets.map!(a => a.shellCommand(gDefaultOptions.withProjectPath("/tmp/myproject"))).array;

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


void testObjectFilesEmpty() {
    dlangPackageObjectFilesPerPackage([]).shouldEqual([]);
    dlangPackageObjectFilesPerModule([]).shouldEqual([]);
}
