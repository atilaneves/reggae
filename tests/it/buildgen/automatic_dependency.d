module tests.it.buildgen.automatic_dependency;


import tests.it.buildgen;
import std.path: buildPath;


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
    import reggae.config: options;

    enum project = "d_and_cpp";
    generateBuild!project;
    shouldBuild!project;
    ["calc", "5"].shouldSucceed.shouldEqual(
        ["The result of calc(10) is 30"]);

    // I don't know what's going on here but the Cucumber test didn't do this either
    if(options.backend == Backend.tup) return;

    overwrite(options, buildPath("src", "constants.d"), "immutable int leconst = 1;");
    shouldBuild!project;

    ["calc", "3"].shouldSucceed.shouldEqual(
        ["The result of calc(3) is 9"]);
}
