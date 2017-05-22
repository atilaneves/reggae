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
    import std.typecons: Yes, No;
    import reggae.config: setOptions;
    import reggae.options: getOptions;

    setOptions(getOptions(["reggae", "/tmp/proj"]));

    DubInfo dubInfo;
    dubInfo.packages = [DubPackage()];
    dubInfo.packages[0].files = ["$KAL_EXT_LIB/liblua.a", "source/luad/foo.d"];
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
                            [compileTarget, Target("$KAL_EXT_LIB/liblua.a")]);

    actual.shouldEqual(expected);
}
