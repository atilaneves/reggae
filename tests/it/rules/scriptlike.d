module tests.it.rules.scriptlike;

import tests.it;

@("template") unittest {
    import reggae.buildgen;
    auto options = _testProjectOptions("binary", "scriptlike");
    string[] noFlags;

    getBuildObject!"scriptlike.reggaefile"(options).shouldEqual(
        Build(Target("calc",
                     Command(CommandType.link, assocListT("flags", noFlags)),
                     [Target("d/main.o",
                             compileCommand("d/main.d", "-debug -O", ["d"], ["resources/text"]),
                             [Target("d/main.d")]),
                      Target("d_logger_constants.o",
                             compileCommand("d.d", "-debug -O", ["d"], ["resources/text"]),
                             [Target("d/logger.d"), Target("d/constants.d")]),
                      Target("cpp/maths.o",
                             compileCommand("cpp/maths.cpp", "-pg"),
                             [Target("cpp/maths.cpp")]),
                      Target("extra/constants.o",
                             compileCommand("extra/constants.cpp", "-pg"),
                             [Target("extra/constants.cpp")]),
                         ])));
}
