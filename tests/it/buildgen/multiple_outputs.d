module tests.it.buildgen.multiple_outputs;

import tests.it.buildgen;
import reggae.path: buildPath;

enum project = "multiple_outputs";


private void doBuild(string module_)(in string reggaefileName, ref Options options) {
    import tests.utils;
    import std.file: remove, rename;

    prepareTestBuild!module_(options);

    const testPath = options.workingDir;
    remove(buildPath(testPath, "protocol.d"));
    rename(buildPath(testPath, reggaefileName), buildPath(testPath, "reggaefile.d"));
    ["dmd", buildPath(testPath, "compiler.d")].shouldExecuteOk(WorkDir(testPath));
    ["dmd", buildPath(testPath, "translator.d")].shouldExecuteOk(WorkDir(testPath));

    justDoTestBuild!module_(options);
}


@("separate")
@AutoTags
@Values("ninja", "make", "binary")
@Tags("travis_oops")
unittest {
    auto options = _testProjectOptions(project);

    enum module_ = "multiple_outputs.reggaefile_sep";
    doBuild!module_("reggaefile_sep.d", options);

    ["app", "2"].shouldSucceed.shouldEqual(["I call protoFunc(2) and get 4"]);

    overwrite(options, "protocol.proto", "int protoFunc(int n) { return n * 3; }");
    buildCmdShouldRunOk!module_(options);

    ["app", "3"].shouldSucceed.shouldEqual(["I call protoFunc(3) and get 9"]);
}


@("together")
@AutoTags
@Values("ninja", "make", "binary")
@Tags("travis_oops")
unittest {
    auto options = _testProjectOptions(project);

    enum module_ = "multiple_outputs.reggaefile_tog";
    doBuild!module_("reggaefile_tog.d", options);

    ["app", "2"].shouldSucceed.shouldEqual(["I call protoFunc(2) and get 4"]);

    overwrite(options, "protocol.proto", "int protoFunc(int n) { return n * 3; }");
    buildCmdShouldRunOk!module_(options);

    ["app", "3"].shouldSucceed.shouldEqual(["I call protoFunc(3) and get 9"]);
}
