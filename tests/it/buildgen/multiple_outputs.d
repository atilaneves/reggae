module tests.it.buildgen.multiple_outputs;

import reggae;
import unit_threaded;
import tests.utils;
import tests.it;
import std.file;
import std.path;
import std.process;


@("separate")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    const backend = getValue!string;
    auto options = testProjectOptions(backend, "multiple_outputs");
    const testPath = options.workingDir;
    enum module_ = "multiple_outputs.reggaefile_sep";

    prepareTestBuild!module_(options);
    remove(buildPath(testPath, "protocol.d"));
    rename(buildPath(testPath, "reggaefile_sep.d"), buildPath(testPath, "reggaefile.d"));
    ["dmd", buildPath(testPath, "compiler.d")].shouldExecuteOk(testPath);
    ["dmd", buildPath(testPath, "translator.d")].shouldExecuteOk(testPath);

    justDoTestBuild!module_(options);
    auto appPath = inPath(testPath, "app");

    [appPath, "2"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(2) and get 4"]);

    overwrite(options, "protocol.proto", "int protoFunc(int n) { return n * 3; }");
    buildCmdShouldRunOk!module_(options);

    [appPath, "3"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(3) and get 9"]);

}


@("together")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    const backend = getValue!string;
    auto options = testProjectOptions(backend, "multiple_outputs");
    const testPath = options.workingDir;
    enum module_ = "multiple_outputs.reggaefile_tog";

    prepareTestBuild!module_(options);
    remove(buildPath(testPath, "protocol.d"));
    rename(buildPath(testPath, "reggaefile_tog.d"), buildPath(testPath, "reggaefile.d"));
    ["dmd", buildPath(testPath, "compiler.d")].shouldExecuteOk(testPath);
    ["dmd", buildPath(testPath, "translator.d")].shouldExecuteOk(testPath);

    justDoTestBuild!module_(options);
    auto appPath = inPath(testPath, "app");

    [appPath, "2"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(2) and get 4"]);

    overwrite(options, "protocol.proto", "int protoFunc(int n) { return n * 3; }");
    buildCmdShouldRunOk!module_(options);

    [appPath, "3"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(3) and get 9"]);
}
