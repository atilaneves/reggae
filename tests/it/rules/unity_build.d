module tests.it.rules.unity_build;


import reggae.path: buildPath;
import tests.it;
import std.algorithm;
import std.path: dirSeparator;
import std.typecons: No;


@("template") unittest {
    import reggae.buildgen;
    import std.array: replace;
    import std.ascii: newline;
    import std.file;
    import std.string;

    auto options = _testProjectOptions("binary", "unity");
    string[] noFlags;

    getBuildObject!"unity.reggaefile"(options).shouldEqual(
        Build(Target("unity",
                     compileCommand("$builddir/.reggae/objs/unity.objs/unity.cpp",
                                    ["-g"], [], [], options.projectPath, No.justCompile),
                     [Target.phony("unity.cpp",
                                   "",
                                   [],
                                   [Target(buildPath("src/main.cpp")),
                                    Target(buildPath("src/maths.cpp"))])]
                  )));

    // should be
    // #include "1st.cpp"
    // #include "2nd.cpp"
    // ...
    const includePrefix = `#include "` ~ options.projectPath.replace(dirSeparator, "/") ~ "/src/";
    readText(buildPath(options.workingDir, ".reggae/objs/unity.objs/unity.cpp")).chomp.split(newline).
        shouldBeSameSetAs(
            ["main.cpp", "maths.cpp"].
            map!(a => includePrefix ~ a ~ `"`));

}
