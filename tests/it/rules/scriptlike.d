module tests.it.rules.scriptlike;

import reggae.path: buildPath;
import tests.it;

@("template") unittest {
    import reggae.buildgen;
    auto options = testProjectOptions("binary", "scriptlike");
    string[] noFlags;

    getBuildObject!"scriptlike.reggaefile"(options).shouldEqual(
        Build(Target("calc",
                     Command(CommandType.link, assocListT("flags", noFlags)),
                     [Target(buildPath("d/main" ~ objExt),
                             compileCommand("d/main.d", ["-debug", "-O"], ["d"], ["resources/text"]),
                             [Target("d/main.d")]),
                      Target("d_logger" ~ objExt,
                             compileCommand("d.d", ["-debug", "-O"], ["d"], ["resources/text"]),
                             [Target(buildPath("d/logger.d")), Target(buildPath("d/constants.d"))]),
                      Target(buildPath("cpp/maths" ~ objExt),
                             compileCommand("cpp/maths.cpp", ["-pg"]),
                             [Target(buildPath("cpp/maths.cpp"))]),
                      Target(buildPath("extra/constants" ~ objExt),
                             compileCommand("extra/constants.cpp", ["-pg"]),
                             [Target(buildPath("extra/constants.cpp"))]),
                         ])));
}
