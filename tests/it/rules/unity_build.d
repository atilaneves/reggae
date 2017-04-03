module tests.it.rules.unity_build;

import tests.it;
import std.path;
import std.algorithm;

@("template") unittest {
    import reggae.buildgen;
    import std.file;
    import std.string;

    auto options = _testProjectOptions("binary", "unity");
    string[] noFlags;

    getBuildObject!"unity.reggaefile"(options).shouldEqual(
        Build(Target("unity",
                     compileCommand("$builddir/objs/unity.objs/unity.cpp",
                                    "-g", [], [], options.projectPath, No.justCompile),
                     [Target.phony("unity.cpp",
                                   "",
                                   [],
                                   [Target("src/main.cpp"), Target("src/maths.cpp")])]
                  )));

    // should be
    // #include "1st.cpp"
    // #include "2nd.cpp"
    // ...
    readText(buildPath(options.workingDir, "objs", "unity.objs", "unity.cpp")).chomp.split("\n").
        shouldBeSameSetAs(
            ["main.cpp", "maths.cpp"].
            map!(a => `#include "` ~ buildPath(options.projectPath, "src", a) ~ `"`));

}
