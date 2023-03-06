module tests.it.rules.static_lib;


import reggae.path: buildPath;
import tests.it;


@Tags("travis_oops")
@("template")
unittest {
    import reggae.buildgen;
    auto options = testProjectOptions("binary", "static_lib");
    string[] noFlags;

    version(Windows)
        enum archiveCmd = "lib.exe /OUT:$out $in";
    else
        enum archiveCmd = "ar rcs $out $in";

    getBuildObject!"static_lib.reggaefile"(options).shouldEqual(
        Build(Target("app",
                     Command(CommandType.link, assocListT("flags", noFlags)),
                     [Target("src/main" ~ objExt,
                             compileCommand("src/main.d", [], ["libsrc"]),
                             [Target("src/main.d")]),
                      Target("$builddir/maths" ~ libExt,
                             archiveCmd,
                             [Target("libsrc_muler" ~ objExt,
                                     compileCommand("libsrc.d", [], ["."]),
                                     [Target(buildPath("libsrc/muler.d")), Target(buildPath("libsrc/adder.d"))]
                                     )]),
                         ])));
}
