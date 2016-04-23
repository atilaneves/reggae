module tests.it.buildgen.multiple_outputs;

import reggae;
import unit_threaded;
import tests.utils;
import tests.it;
import std.file;
import std.path;
import std.process;


private void doBuild(string module_)(in string reggaefileName, ref Options options) {
    prepareTestBuild!module_(options);

    const testPath = options.workingDir;
    remove(buildPath(testPath, "protocol.d"));
    rename(buildPath(testPath, reggaefileName), buildPath(testPath, "reggaefile.d"));
    ["dmd", buildPath(testPath, "compiler.d")].shouldExecuteOk(testPath);
    ["dmd", buildPath(testPath, "translator.d")].shouldExecuteOk(testPath);

    justDoTestBuild!module_(options);
}


@("separate")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    auto options = testProjectOptions("multiple_outputs");

    enum module_ = "multiple_outputs.reggaefile_sep";
    doBuild!module_("reggaefile_sep.d", options);

    auto appPath = inPath(options, "app");

    [appPath, "2"].shouldExecuteOk(options).shouldEqual(
        ["I call protoFunc(2) and get 4"]);

    overwrite(options, "protocol.proto", "int protoFunc(int n) { return n * 3; }");
    buildCmdShouldRunOk!module_(options);

    [appPath, "3"].shouldExecuteOk(options).shouldEqual(
        ["I call protoFunc(3) and get 9"]);

}


@("together")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    auto options = testProjectOptions("multiple_outputs");
    enum module_ = "multiple_outputs.reggaefile_tog";

    doBuild!module_("reggaefile_tog.d", options);

    auto appPath = inPath(options, "app");

    [appPath, "2"].shouldExecuteOk(options).shouldEqual(
        ["I call protoFunc(2) and get 4"]);

    overwrite(options, "protocol.proto", "int protoFunc(int n) { return n * 3; }");
    buildCmdShouldRunOk!module_(options);

    [appPath, "3"].shouldExecuteOk(options).shouldEqual(
        ["I call protoFunc(3) and get 9"]);
}
