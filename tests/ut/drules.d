module tests.ut.drules;


import reggae;
import reggae.options;
import reggae.path: buildPath;
import reggae.backend.ninja;
import unit_threaded;
import std.algorithm;
import std.array;


@("DCompile no include paths Ninja") unittest {
    auto build = Build(objectFile(Options(), SourceFile("path/to/src/foo.d")));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _dcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.d"),
                    [])]);
}


@("DCompile include paths Ninja") unittest {
    auto build = Build(objectFile(Options(), SourceFile("path/to/src/foo.d"),
                                   Flags("-O"),
                                   ImportPaths(["path/to/src", "other/path"])));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("path/to/src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry("build " ~ objPath ~ ": _dcompile " ~ buildPath("/tmp/myproject/path/to/src/foo.d"),
                    ["includes = -I" ~ buildPath("/tmp/myproject/path/to/src") ~ " -I" ~ buildPath("/tmp/myproject/other/path"),
                     "flags = -O"])]);
}

@("DCompile with spaces Ninja") unittest {
    auto build = Build(objectFile(Options(), SourceFile("my src/foo.d"),
                                   Flags(["-O", "-L/LIBPATH:my libs"]),
                                   ImportPaths(["my src", "other/path"])));
    auto ninja = Ninja(build, "/tmp/myproject");
    enum objPath = buildPath("my src/foo" ~ objExt);
    ninja.buildEntries.shouldEqual(
        [NinjaEntry(`build ` ~ buildPath("my$ src/foo") ~ objExt ~ `: _dcompile ` ~ buildPath("/tmp/myproject/my$ src/foo.d"),
                    [`includes = "-I` ~ buildPath("/tmp/myproject/my src") ~ `" -I` ~ buildPath("/tmp/myproject/other/path"),
                     `flags = -O "-L/LIBPATH:my libs"`])]);
}


@ShouldFail
@("dlangObjectFilesPerPackage")
unittest {
    auto build = Build(dlangObjectFilesPerPackage(options,
                                                  ["path/to/src/foo.d",
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
    auto build = Build(dlangObjectFilesPerModule(Options(), ["/project/source/main.d",
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


@("Object files empty") unittest {
    dlangObjectFilesPerPackage(options, []).shouldBeEmpty;
    dlangObjectFilesPerModule(options, []).shouldBeEmpty;
}
