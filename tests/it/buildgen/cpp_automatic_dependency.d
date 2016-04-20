module tests.it.buildgen.cpp_automatic_dependency;


import reggae;
import unit_threaded;
import tests.utils;
import tests.it;


@("C++ dependencies get automatically computed with objectFile")
@AutoTags
@Values("ninja", "make", "tup", "binary")
unittest {
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "d_and_cpp")]);
    enum module_ = "d_and_cpp.reggaefile";
    doTestBuildFor!module_(options);

    auto testPath = options.workingDir;
    auto appPath = inPath(testPath, "calc");
    [appPath, "5"].shouldExecuteOk(testPath).shouldEqual(
        ["The result of calc(5) is 15"]);

    // I don't know what's going on here but the Cucumber test didn't do this either
    if(backend == "tup") return;

    // ninja has problems with timestamp differences that are less than a second apart
    if(backend == "ninja") {
        import core.thread;
        writelnUt("Sleeping before changing file");
        Thread.sleep(1.seconds);
    }

    // overwriting maths.hpp should cause a recompilation
    {
        import std.stdio;
        import std.path;
        auto file = File(buildPath(testPath, "src", "maths.hpp"), "w");
        file.writeln("const int factor = 10;");
    }

    // rebuild
    buildCmdShouldRunOk!module_(options);

    // check new output
    [appPath, "3"].shouldExecuteOk(testPath).shouldEqual(
        ["The result of calc(3) is 30"]);
}
