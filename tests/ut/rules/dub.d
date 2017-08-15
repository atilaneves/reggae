module tests.ut.rules.dub;


import reggae;
import unit_threaded;


@("dubTarget with lflags")
unittest {

    import reggae.rules.dub: dubTarget;
    import std.typecons: Yes, No;

    DubInfo dubInfo;
    dubInfo.packages = [DubPackage()];
    dubInfo.packages[0].lflags = ["-L$FOO"];
    Target[] objects;
    const actual = dubTarget!()(TargetName("app"),
                                dubInfo,
                                "-g -debug",
                                [],
                                Yes.main,
                                No.allTogether,
    );
    const expected = Target("app",
                            Command(CommandType.link,
                                    assocList([assocEntry("flags",
                                                          ["-L-L$FOO"])])),
                            []);
    actual.shouldEqual(expected);
}



@("dubTarget with static library source with env var in path")
unittest {

    import reggae.rules.dub: dubTarget;
    import reggae.config: setOptions;
    import reggae.options: getOptions;
    import std.typecons: Yes, No;
    import std.algorithm: filter;
    import std.array: split;

    setOptions(getOptions(["reggae", "/tmp/proj"]));

    DubInfo dubInfo;
    dubInfo.packages = [DubPackage()];
    dubInfo.packages[0].files = ["$LIB/liblua.a", "source/luad/foo.d"];
    dubInfo.packages[0].importPaths = ["source"];
    Target[] objects;
    const actual = dubTarget!()(TargetName("app"),
                                dubInfo,
                                "-g -debug",
                                [],
                                Yes.main,
                                No.allTogether,
    );

    string[] empty;

    auto compileTarget = Target("source/luad.o",
                                Command(CommandType.compile,
                                        assocList(
                                             [
                                                 assocEntry("includes", ["-Isource", "-I/tmp/proj"]),
                                                 assocEntry("flags", ["-g", "-debug"]),
                                                 assocEntry("stringImports", empty),
                                                 assocEntry("DEPFILE", ["source/luad.o.dep"])
                                             ])),
                                 [Target("source/luad/foo.d")],
    );

    const expected = Target("app",
                            Command(CommandType.link,
                                    assocList([assocEntry("flags",
                                                          empty)])),
                            [compileTarget, Target("$LIB/liblua.a")]);

    actual.shouldEqual(expected);
    Options options;
    options.dCompiler = "dmd";
    options.projectPath = "/proj";
    actual.shellCommand(options).split(" ").filter!(a => a != "").
        shouldEqual(["dmd", "-ofapp", "source/luad.o", "$LIB/liblua.a"]);
}

//FIXME: includes should not have all of them
@("versions from main package apply to all packages")
unittest {

    import reggae.rules.dub: dubTarget;
    import reggae.config: options, setOptions;
    import std.typecons: Yes, No;

    auto oldOptions = options;
    scope(exit) setOptions(oldOptions);
    auto newOptions = oldOptions.dup;
    newOptions.perModule = true;
    newOptions.projectPath = "/leproj";
    setOptions(newOptions);

    DubInfo dubInfo;
    dubInfo.packages = [DubPackage("myapp", "/path/myapp"), DubPackage("dep", "/path/dep")];
    dubInfo.packages[0].files = ["src/file1.d", "src/file2.d"];
    dubInfo.packages[0].importPaths = ["/path/myapp/src"];
    dubInfo.packages[0].versions = ["foo", "bar"];
    dubInfo.packages[0].dependencies = ["dep"];
    dubInfo.packages[1].files = ["source/dep1.d", "source/dep2.d"];
    dubInfo.packages[1].importPaths = ["/path/dep/source"];
    dubInfo.packages[1].versions = ["quux"];

    Target[] objects;
    const actual = dubTarget!()(TargetName("app"),
                                dubInfo,
                                "-g",
                                [],
                                Yes.main,
                                No.allTogether,
    );
    string[] empty;
    const expected =
        Target("app",
               Command(CommandType.link,
                       assocList([assocEntry("flags",
                                             empty)])),
               [
                   Target("path/myapp/src/file1.o",
                          Command(CommandType.compile,
                                  assocList([
                                                assocEntry("includes",
                                                           ["-I/path/myapp/src", "-I/path/dep/source", "-I/leproj"]),
                                                assocEntry("flags", ["-version=foo", "-version=bar", "-version=quux", "-g"]),
                                                assocEntry("stringImports", empty),
                                                assocEntry("DEPFILE", ["path/myapp/src/file1.o.dep"])
                                                      ])),
                          [Target("/path/myapp/src/file1.d")]),

                   Target("path/myapp/src/file2.o",
                          Command(CommandType.compile,
                                  assocList([
                                                assocEntry("includes",
                                                           ["-I/path/myapp/src", "-I/path/dep/source", "-I/leproj"]),
                                                assocEntry("flags", ["-version=foo", "-version=bar", "-version=quux", "-g"]),
                                                assocEntry("stringImports", empty),
                                                             assocEntry("DEPFILE", ["path/myapp/src/file2.o.dep"])
                                                ])),
                          [Target("/path/myapp/src/file2.d")]),

                   Target("path/dep/source/dep1.o",
                          Command(CommandType.compile,
                                  assocList([
                                                assocEntry("includes",
                                                           ["-I/path/myapp/src", "-I/path/dep/source", "-I/leproj"]),
                                                assocEntry("flags", ["-version=foo", "-version=bar", "-version=quux", "-g"]),
                                                assocEntry("stringImports", empty),
                                                assocEntry("DEPFILE", ["path/dep/source/dep1.o.dep"])
                                                ])),
                          [Target("/path/dep/source/dep1.d")]),

                   Target("path/dep/source/dep2.o",
                          Command(CommandType.compile,
                                  assocList([
                                                assocEntry("includes",
                                                           ["-I/path/myapp/src", "-I/path/dep/source", "-I/leproj"]),
                                                assocEntry("flags", ["-version=foo", "-version=bar", "-version=quux", "-g"]),
                                                assocEntry("stringImports", empty),
                                                assocEntry("DEPFILE", ["path/dep/source/dep2.o.dep"])
                                                ])),
                          [Target("/path/dep/source/dep2.d")]),

             ]
        );
    actual.shouldEqual(expected);
}


@("static library dubConfigurationTarget")
unittest {
    auto oldOptions = options;
    scope(exit) setOptions(oldOptions);

    auto newOptions = oldOptions.dup;
    newOptions.perModule = false;
    newOptions.projectPath = "/leproj";
    setOptions(newOptions);

    auto dubInfo = DubInfo([DubPackage("myapp", "/path/myapp")]);
    dubInfo.packages[0].files = ["src/file1.d", "src/file2.d"];
    dubInfo.packages[0].targetType = TargetType.library;

    string[] empty;
    const expected = Target("$builddir/libfoo.a",
                            Command("ar rcs $out $in"),
                            [Target("path/myapp/src.o",
                                    Command(CommandType.compile,
                                            assocList([
                                                          assocEntry("includes", ["-I/leproj"]),
                                                          assocEntry("flags", ["-g"]),
                                                          assocEntry("stringImports", empty),
                                                          assocEntry("DEPFILE", ["path/myapp/src.o.dep"]),
                                                          ])),
                                    [Target("/path/myapp/src/file1.d"), Target("/path/myapp/src/file2.d")])]);
    dubTarget(TargetName("libfoo.a"), dubInfo, "-g").shouldEqual(expected);
}

@("object files as dub srcFiles")
unittest {
    auto oldOptions = options;
    scope(exit) setOptions(oldOptions);

    auto newOptions = oldOptions.dup;
    newOptions.perModule = false;
    newOptions.projectPath = "/leproj";
    setOptions(newOptions);

    auto dubInfo = DubInfo([DubPackage("myapp", "/path/myapp")]);
    dubInfo.packages[0].files = ["src/file1.d", "src/file2.d", "bin/dep.o"];

    string[] empty;
    const expected = Target("libfoo.a",
                            Command(CommandType.link, assocList([assocEntry("flags", empty)])),
                            [
                                Target("path/myapp/src.o",
                                       Command(CommandType.compile,
                                               assocList([
                                                             assocEntry("includes", ["-I/leproj"]),
                                                             assocEntry("flags", ["-g"]),
                                                             assocEntry("stringImports", empty),
                                                             assocEntry("DEPFILE", ["path/myapp/src.o.dep"]),
                                                         ])),
                                       [Target("/path/myapp/src/file1.d"), Target("/path/myapp/src/file2.d")]),

                                Target("/path/myapp/bin/dep.o"),
                            ]);
    dubTarget(TargetName("libfoo.a"), dubInfo, "-g").shouldEqual(expected);
}
