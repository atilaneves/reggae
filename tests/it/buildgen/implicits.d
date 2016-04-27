module tests.it.buildgen.implicits;


import tests.it;
import tests.utils;
import std.path;


@("Implicit dependencies cause the target to rebuild")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    auto options = testProjectOptions("implicits");
    enum module_ = "implicits.reggaefile";
    doTestBuildFor!module_(options);

    const testPath = options.workingDir;
    const appPath = inPath(testPath, "leapp");

    appPath.shouldExecuteOk(testPath).shouldEqual(
        ["Hello world!"]);

    overwrite(options, buildPath("string.txt"), "Goodbye!");
    buildCmdShouldRunOk!module_(options);

    // check new output
    appPath.shouldExecuteOk(testPath).shouldEqual(
        ["Goodbye!"]);
}
