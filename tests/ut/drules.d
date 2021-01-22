module tests.ut.drules;


import reggae;
import reggae.options;
import reggae.path: buildPath;
import reggae.backend.ninja;
import unit_threaded;
import std.algorithm;
import std.array;


void testDCompileNoIncludePathsNinja() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.d")));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _dcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.d"),
                    [])]);
}


void testDCompileIncludePathsNinja() {
    auto build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _dcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.d"),
                    ["includes = -I" ~ buildPath("/tmp/myproject/path/to/src") ~ " -I" ~ buildPath("/tmp/myproject/other/path"),
                     "flags = -O"])]);
}

void testDCompileIncludePathsMake() {
    import reggae.config: gDefaultOptions;

    auto build = Build(objectFile(SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    version(Windows)
        enum defaultDCModel = " -m32mscoff";
    else
        enum defaultDCModel = null;
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    build.targets.array[0].shellCommand(gDefaultOptions.withProjectPath("/tmp/myproject")).shouldEqual(
        buildPath(".reggae/dcompile") ~ " --objFile=" ~ objPath ~ " --depFile=" ~ objPath ~ ".dep dmd" ~ defaultDCModel ~ " -O " ~
        "-I" ~ buildPath("/tmp/myproject/path/to/src") ~ " -I" ~ buildPath("/tmp/myproject/other/path") ~ "  " ~ buildPath("/tmp/myproject/path/to/src/foo.d"));
}


@ShouldFail
@("dlangObjectFilesPerPackage")
unittest {
    auto build = Build(dlangObjectFilesPerPackage(["path/to/src/foo.d",
                                                   "path/to/src/bar.d",
                                                   "other/weird.d"],
                                                  ["-O"], ["path/to/src", "other/path"]));
    build.shouldEqual(Build(Target("path/to/src.o",
                                   compileCommand("path/to/src.d",
                                                  ["-O"],
                                                  ["path/to/src", "other/path"]),
                                   [Target("path/to/src/foo.d"), Target("path/to/src/bar.d")]),
                            Target("other.o",
                                   compileCommand("other.d",
                                                  ["-O"],
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
    build.shouldEqual(Build(Target(buildPath("project/source/main" ~ objExt),
                                   compileCommand("/project/source/main.d"),
                                   Target("/project/source/main.d")),
                            Target(buildPath("project/__/__/common/source/foo" ~ objExt),
                                   compileCommand("/project/../../common/source/foo.d"),
                                   Target("/project/../../common/source/foo.d")),
                            Target(buildPath("project/__/__/common/source/bar" ~ objExt),
                                   compileCommand("/project/../../common/source/bar.d"),
                                   Target("/project/../../common/source/bar.d")),
                          ));
}


void testObjectFilesEmpty() {
    dlangObjectFilesPerPackage([]).shouldEqual([]);
    dlangObjectFilesPerModule([]).shouldEqual([]);
}
