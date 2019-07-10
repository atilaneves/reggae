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


@ShouldFail
@("dlangObjectFilesPerPackage")
unittest {
    auto build = Build(dlangObjectFilesPerPackage(["path/to/src/foo.d",
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

@("dlangObjectFilesPerPackage ..")
unittest {
    auto build = Build(dlangObjectFilesPerModule(["/project/source/main.d",
                                                  "/project/../../common/source/foo.d",
                                                  "/project/../../common/source/bar.d",
                                                 ]));
    build.shouldEqual(Build(Target("project/source/main.o",
                                   compileCommand("/project/source/main.d"),
                                   Target("/project/source/main.d")),
                            Target("project/__/__/common/source/foo.o",
                                   compileCommand("/project/../../common/source/foo.d"),
                                   Target("/project/../../common/source/foo.d")),
                            Target("project/__/__/common/source/bar.o",
                                   compileCommand("/project/../../common/source/bar.d"),
                                   Target("/project/../../common/source/bar.d")),
                          ));
}


void testObjectFilesEmpty() {
    dlangObjectFilesPerPackage([]).shouldEqual([]);
    dlangObjectFilesPerModule([]).shouldEqual([]);
}

void testObjectFilesImplicitTargets() {
    auto build = Build(dlangObjectFilesPerPackage(["foo.d"],
                                                  "-O",
                                                  ["include"],
                                                  [],
                                                  [Target("f.json")]));

    build.shouldEqual(Build(Target("foo.o",
                                   compileCommand("foo.d",
                                                  "-O",
                                                  ["include"]),
                                   [Target("path/to/src/foo.d")],
                                   [Target("f.json")])));
}
