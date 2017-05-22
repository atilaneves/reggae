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
    const actual = dubTarget!()(ExeName("app"),
                                dubInfo,
                                "-g -debug",
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
    const actual = dubTarget!()(ExeName("app"),
                                dubInfo,
                                "-g -debug",
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
