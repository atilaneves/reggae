
module tests.it.rules.object_files;


import reggae;
import unit_threaded;
import tests.it;
import std.path;
import std.file;
import std.stdio: File;


@("C++ files with template objectFiles") unittest {
    import reggae.buildgen;
    auto options = testProjectOptions("binary", "template_rules");
    string[] flags;

    getBuildObject!"template_rules.reggaefile"(options).shouldEqual(
        Build(Target("app",
                     Command(CommandType.link, assocListT("flags", flags)),
                     [Target("main.o", compileCommand("main.cpp", "-g -O0"), [Target("main.cpp")]),
                      Target("maths.o", compileCommand("maths.cpp", "-g -O0"), [Target("maths.cpp")])]
                  )));
}

@("C++ files with regular objectFiles") unittest {
    auto testPath = newTestDir.absolutePath;
    mkdir(buildPath(testPath, "proj"));
    foreach(fileName; ["main.cpp", "maths.cpp", "intermediate.hpp", "final.hpp" ]) {
        auto f = File(buildPath(testPath, "proj", fileName), "w");
        f.writeln;
    }

    string[] none;
    objectFiles(testPath, ["."], none, none, none, "-g -O0").shouldBeSameSetAs(
        [Target("proj/main.o",
                compileCommand("proj/main.cpp", "-g -O0"),
                [Target("proj/main.cpp")]),
         Target("proj/maths.o",
                compileCommand("proj/maths.cpp", "-g -O0"),
                [Target("proj/maths.cpp")])]
    );
}
