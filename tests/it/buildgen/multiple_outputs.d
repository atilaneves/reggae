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

    prepareTestBuild!"multiple_outputs.reggaefile_sep"(options);
    remove(buildPath(testPath, "protocol.d"));
    rename(buildPath(testPath, "reggaefile_sep.d"), buildPath(testPath, "reggaefile.d"));
    ["dmd", buildPath(testPath, "compiler.d")].shouldExecuteOk(testPath);
    ["dmd", buildPath(testPath, "translator.d")].shouldExecuteOk(testPath);

    justDoTestBuild!"multiple_outputs.reggaefile_sep"(options);

    auto appPath = inPath(testPath, "app");
    [appPath, "2"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(2) and get 4"]);
}


@("together")
@AutoTags
@Values("ninja", "make", "binary")
unittest {
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "multiple_outputs")]);
    auto testPath = options.workingDir;

    prepareTestBuild!"multiple_outputs.reggaefile_tog"(options);
    remove(buildPath(testPath, "protocol.d"));
    rename(buildPath(testPath, "reggaefile_tog.d"), buildPath(testPath, "reggaefile.d"));
    ["dmd", buildPath(testPath, "compiler.d")].shouldExecuteOk(testPath);
    ["dmd", buildPath(testPath, "translator.d")].shouldExecuteOk(testPath);

    justDoTestBuild!"multiple_outputs.reggaefile_tog"(options);

    auto appPath = inPath(testPath, "app");
    [appPath, "2"].shouldExecuteOk(testPath).shouldEqual(
        ["I call protoFunc(2) and get 4"]);
}
