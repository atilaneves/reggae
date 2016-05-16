module tests.it.runtime.dub;


import tests.it.runtime;
import reggae.reggae;
import std.path;


private string prepareTestPath(in string projectName) {
    const testPath = newTestDir;
    const projPath = buildPath(origPath, "tests", "projects", projectName);
    copyProjectFiles(projPath, testPath);
    return testPath;
}

@("dub project with no reggaefile ninja")
@Tags(["dub", "ninja"])
unittest {

    with(ReggaeSandbox()) {
        copyProject("dub");
        shouldNotExist("reggaefile.d");
        runReggae("-b", "ninja", "--dflags=-g -debug");
        shouldExist("reggaefile.d");
        auto output = ninja.shouldExecuteOk(testPath);
        output.shouldContain("-g -debug");

        shouldSucceed("atest").shouldEqual(
            ["Why hello!",
             "",
             "[0, 0, 0, 4]",
             "I'm immortal!"]
        );

        // there's only one UT in main.d which always fails
        shouldFail("ut");
    }
}

@("dub project with no reggaefile tup")
@Tags(["dub", "tup"])
unittest {
    with(ReggaeSandbox()) {
        copyProject("dub");
        runReggae("-b", "tup", "--dflags=-g -debug").
            shouldThrowWithMessage("dub integration not supported with the tup backend");
    }
}

@("dub project with no reggaefile and prebuild command")
@Tags(["dub", "ninja"])
unittest {
    with(ReggaeSandbox()) {
        copyProject("dub_prebuild");
        runReggae("-b", "ninja", "--dflags=-g -debug");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("ut");
    }
}

@("dub project with no target type")
@Tags(["dub", "ninja"])
unittest {

    with(ReggaeSandbox()) {
        writeFile("dub.json", `
{
  "name": "notargettype",
  "license": "MIT",
  "targetType": "none"
}`);

        runReggae("-b", "ninja", "--dflags=-g -debug").shouldThrowWithMessage(
        "Unsupported dub targetType 'none'");
    }
}
