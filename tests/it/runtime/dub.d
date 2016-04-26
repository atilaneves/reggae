module tests.it.runtime.dub;


import tests.it;
import tests.utils;
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
    import std.algorithm;
    import std.file;

    const testPath = prepareTestPath("dub");

    buildPath(testPath, "reggaefile.d").exists.shouldBeFalse;
    run(["reggae", "-C", testPath, "-b", "ninja", `--dflags=-g -debug`, testPath]);
    buildPath(testPath, "reggaefile.d").exists.shouldBeTrue;

    auto output = ninja.shouldExecuteOk(testPath);
    output.canFind!(a => a.canFind("-g -debug")).shouldBeTrue;

    inPath(testPath, "atest").shouldExecuteOk(testPath).shouldEqual(
        ["Why hello!",
         "",
         "[0, 0, 0, 4]",
         "I'm immortal!"]
        );

    // there's only one UT in main.d which always fails
    inPath(testPath, "ut").shouldFailToExecute(testPath);
}

@("dub project with no reggaefile tup")
@Tags(["dub", "tup"])
unittest {
    const testPath = prepareTestPath("dub");

    run(["reggae", "-C", testPath, "-b", "tup", `--dflags=-g -debug`, testPath]).
        shouldThrowWithMessage("dub integration not supported with the tup backend");
}

@("dub project with no reggaefile and prebuild command")
@Tags(["dub", "ninja"])
unittest {

    const testPath = prepareTestPath("dub_prebuild");
    run(["reggae", "-C", testPath, "-b", "ninja", `--dflags=-g -debug`, testPath]);

    ninja.shouldExecuteOk(testPath);
    inPath(testPath, "ut").shouldExecuteOk(testPath);
}
