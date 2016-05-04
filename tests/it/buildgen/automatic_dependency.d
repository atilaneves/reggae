module tests.it.buildgen.automatic_dependency;

import tests.it.buildgen;


@("C++ dependencies get automatically computed with objectFile")
@AutoTags
@Values("ninja", "make", "tup", "binary")
unittest {
    import reggae.config: options;

    enum project = "d_and_cpp";
    generateBuild!project;
    shouldBuild!project;
    ["calc", "5"].shouldSucceed.shouldEqual(
        ["The result of calc(10) is 30"]);

    // I don't know what's going on here but the Cucumber test didn't do this either
    if(options.backend == Backend.tup) return;

    overwrite(options, buildPath("src", "maths.hpp"), "const int factor = 10;");
    shouldBuild!project;

    ["calc", "3"].shouldSucceed.shouldEqual(
        ["The result of calc(6) is 60"]);
}

@("D dependencies get automatically computed with objectFile")
@AutoTags
@Values("ninja", "make", "tup", "binary")
unittest {
    import std.path;
    import tests.utils;
    const backend = getValue!string;
    auto options = testProjectOptions(backend, "d_and_cpp");
    enum module_ = "d_and_cpp.reggaefile";
    doTestBuildFor!module_(options);

    const testPath = options.workingDir;
    const appPath = inPath(testPath, "calc");

    [appPath, "5"].shouldExecuteOk(testPath).shouldEqual(
        ["The result of calc(10) is 30"]);

    // I don't know what's going on here but the Cucumber test didn't do this either
    if(options.backend == Backend.tup) return;

    overwrite(options, buildPath("src", "constants.d"), "immutable int leconst = 1;");
    buildCmdShouldRunOk!module_(options);

    // check new output
    [appPath, "3"].shouldExecuteOk(testPath).shouldEqual(
        ["The result of calc(3) is 9"]);
}
