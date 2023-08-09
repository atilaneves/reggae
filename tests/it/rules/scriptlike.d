module tests.it.rules.scriptlike;

version(DigitalMars):

import reggae.path: buildPath;
import tests.it;

@Flaky
@("template")
unittest {
    import reggae.buildgen;
    import std.path: baseName;
    import std.algorithm: map, joiner;

    auto options = testProjectOptions("binary", "scriptlike");
    string[] noFlags;

    auto buildObj = getBuildObject!"scriptlike.reggaefile"(options);
    buildObj.targets.length.should == 1;
    auto topLevel = buildObj.targets[0];
    auto targets = topLevel.dependencyTargets;
    writelnUt("targets: ", targets);
    targets.length.shouldBeGreaterThan(2);
    // the only thing that matters really is that the dependencies of the
    // script were calculated correctly
    targets[1]
        .dependencyTargets
        .map!(t => t.rawOutputs.map!baseName)
        .joiner
        .should ==
    [
        "logger.d",
        "constants.d",
    ];

    // getBuildObject!"scriptlike.reggaefile"(options).shouldEqual(
    //     Build(Target("calc",
    //                  Command(CommandType.link, assocListT("flags", noFlags)),
    //                  [Target(buildPath("d/main" ~ objExt),
    //                          compileCommand("d/main.d", ["-debug", "-O"], ["d"], ["resources/text"]),
    //                          [Target("d/main.d")]),
    //                   Target("d_logger" ~ objExt,
    //                          compileCommand("d.d", ["-debug", "-O"], ["d"], ["resources/text"]),
    //                          [Target(buildPath("d/logger.d")), Target(buildPath("d/constants.d"))]),
    //                   Target(buildPath("cpp/maths" ~ objExt),
    //                          compileCommand("cpp/maths.cpp", ["-pg"]),
    //                          [Target(buildPath("cpp/maths.cpp"))]),
    //                   Target(buildPath("extra/constants" ~ objExt),
    //                          compileCommand("extra/constants.cpp", ["-pg"]),
    //                          [Target(buildPath("extra/constants.cpp"))]),
    //                      ])));
}
