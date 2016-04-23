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
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "multiple_outputs")]);
    auto testPath = options.workingDir;

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

    // ninja has problems with timestamp differences that are less than a second apart
    if(backend == "ninja") {
        import core.thread;
        writelnUt("Sleeping before changing file");
        Thread.sleep(1.seconds);
    }

    {
        import std.stdio: File;
        auto file = File(buildPath(testPath, "protocol.proto"), "w");
        file.writeln("int protoFunc(int n) { return n * 3; }");
    }

    // rebuild
    buildCmdShouldRunOk!module_(options);

    [appPath, "3"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(3) and get 9"]);

}


@("together")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "multiple_outputs")]);
    auto testPath = options.workingDir;
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

    // ninja has problems with timestamp differences that are less than a second apart
    if(backend == "ninja") {
        import core.thread;
        writelnUt("Sleeping before changing file");
        Thread.sleep(1.seconds);
    }

    {
        import std.stdio: File;
        auto file = File(buildPath(testPath, "protocol.proto"), "w");
        file.writeln("int protoFunc(int n) { return n * 3; }");
    }

    // rebuild
    buildCmdShouldRunOk!module_(options);

    [appPath, "3"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(3) and get 9"]);
}
