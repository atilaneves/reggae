module tests.it.rules.static_lib;

import tests.it;

@("template") unittest {
    import reggae.buildgen;
    auto options = testProjectOptions("binary", "static_lib");
    string[] noFlags;

    getBuildObject!"static_lib.reggaefile"(options).shouldEqual(
        Build(Target("app",
                     Command(CommandType.link, assocListT("flags", noFlags)),
                     [Target("src/main.o",
                             compileCommand("src/main.d", "", ["libsrc"]),
                             [Target("src/main.d")]),
                      Target("$builddir/maths.a",
                             "ar rcs $out $in",
                             [Target("libsrc.o",
                                     compileCommand("libsrc.d", "", ["."]),
                                     [Target("libsrc/muler.d"), Target("libsrc/adder.d")]
                                     )]),
                         ])));
}
