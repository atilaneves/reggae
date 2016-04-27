module tests.it.buildgen.export_;


import tests.it;
import tests.utils;
import std.path;
import std.file;
import std.string;
import std.conv;


@("Export build system")
@AutoTags
@Values("ninja", "make", "tup")
unittest {
    auto options = testOptions(["--export", projectPath("export_proj")]);
    enum module_ = "export_proj.reggaefile";
    doTestBuildFor!module_(options);

    const testPath = options.workingDir;
    const appPath = inPath(testPath, "hello");

    // no app yet, just exported the build
    appPath.shouldFailToExecute(testPath);

    // try one of the build systems and build the app
    buildCmd(getValue!string.to!Backend, testPath).shouldExecuteOk(testPath);

    // it should now run ok
    appPath.shouldExecuteOk.shouldEqual(
        ["Hello world!"]);
}
