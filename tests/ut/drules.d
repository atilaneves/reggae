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


@("dlangPackageObjectFilesPerPackage")
unittest {
    auto build = Build(dlangPackageObjectFilesPerPackage(["path/to/src/foo.d",
                                                          "path/to/src/bar.d",
                                                          "other/weird.d"],
                                              "-O", ["path/to/src", "other/path"]));
    build.shouldEqual(Build(Target("path/to/src.o",
                                   compileCommand("path/to/src.d",
                                                  "-O",
                                                  ["path/to/src", "other/path"]),
                                   [Target("path/to/src/foo.d"), Target("path/to/src/bar.d")]),
                            Target("other.o",
                                   compileCommand("other.d",
                                                  "-O",
                                                  ["path/to/src", "other/path"]),
                                   [Target("other/weird.d")]),
                          ));
}


void testObjectFilesEmpty() {
    dlangPackageObjectFilesPerPackage([]).shouldEqual([]);
    dlangPackageObjectFilesPerModule([]).shouldEqual([]);
}
