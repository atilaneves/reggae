module tests.it.buildgen.cpp_automatic_dependency;


import reggae;
import unit_threaded;
import tests.utils;
import tests.it;


@("C++ dependencies get automatically computed with objectFile")
@AutoTags
@Values("ninja", "make", "tup", "binary")
unittest {
    auto backend = getValue!string;
    auto options = testOptions(["-b", backend, inOrigPath("tests", "projects", "d_and_cpp")]);
    doTestBuildFor!"d_and_cpp.reggaefile"(options);

    auto testPath = options.workingDir;
    auto appPath = inPath(testPath, "calc");
    [appPath, "5"].shouldExecuteOk(testPath).shouldEqual(
        ["The result of calc(5) is 15",
      ]);
}
