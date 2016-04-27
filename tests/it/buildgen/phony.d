module tests.it.buildgen.phony;


import tests.it;
import tests.utils;
import std.path;
import std.file;
import std.string;


@("Phony target always executed")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    auto options = testProjectOptions("phony_proj");
    enum module_ = "phony_proj.reggaefile";
    doTestBuildFor!module_(options);

    const testPath = options.workingDir;
    const appPath = inPath(testPath, "app");

    // haven't run the binary yet, no output
    buildPath(testPath, "output.txt").exists.shouldBeFalse;

    // "build" the phony target doit
    buildCmdShouldRunOk!module_(options, ["doit"]);
    readText(buildPath(testPath, "output.txt")).chomp.split("\n").shouldEqual(
        ["It is done"]);

    // "rebuild" the phony target doit should cause it to run again
    buildCmdShouldRunOk!module_(options, ["doit"]);
    readText(buildPath(testPath, "output.txt")).chomp.split("\n").shouldEqual(
        ["It is done",
         "It is done"]);

}
