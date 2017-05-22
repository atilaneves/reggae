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
    auto compileTarget = Target("source.o",
                                Command(CommandType.compile,
                                        assocList(
                                             [
                                                 assocEntry("includes", ["-Isource", "-I"]),
                                                 assocEntry("flags", ["-g", "-debug"]),
                                                 assocEntry("DEPFILE", ["source.o.dep"])
                                             ])),
                                 [Target("source/luad/foo.d")],
    );

    string[] empty;
    const expected = Target("app",
                            Command(CommandType.link,
                                    assocList([assocEntry("flags",
                                                          empty)])),
                            [compileTarget, Target("$KAL_EXT_LIB/liblua.a")]);

    actual.shouldEqual(expected);
}
