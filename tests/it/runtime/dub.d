module tests.it.runtime.dub;


import tests.it;
import tests.utils;
import reggae.reggae;
import std.path;
import std.file;
import std.algorithm;


@("dub project with no reggaefile ninja")
@Tags(["dub", "ninja"])
unittest {

    const testPath = newTestDir;
    const projPath = buildPath(origPath, "tests", "projects", "dub");

    foreach(entry; dirEntries(projPath, SpanMode.depth)) {
        if(entry.isDir) continue;
        auto tgtName = buildPath(testPath, entry.relativePath(projPath));
        auto dir = dirName(tgtName);
        if(!dir.exists) mkdirRecurse(dir);
        copy(entry, buildPath(testPath, tgtName));
    }

    buildPath(testPath, "reggaefile.d").exists.shouldBeFalse;
    run(["reggae", "-C", testPath, "-b", "ninja", `--dflags=-g -debug`, testPath]);
    buildPath(testPath, "reggaefile.d").exists.shouldBeTrue;

    auto output = ninja.shouldExecuteOk(testPath);
    output.canFind!(a => a.canFind("-g -debug")).shouldBeTrue;

    inPath(testPath, "atest").shouldExecuteOk.shouldEqual(
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

    const testPath = newTestDir;
    const projPath = buildPath(origPath, "tests", "projects", "dub");

    foreach(entry; dirEntries(projPath, SpanMode.depth)) {
        if(entry.isDir) continue;
        auto tgtName = buildPath(testPath, entry.relativePath(projPath));
        auto dir = dirName(tgtName);
        if(!dir.exists) mkdirRecurse(dir);
        copy(entry, buildPath(testPath, tgtName));
    }

    buildPath(testPath, "reggaefile.d").exists.shouldBeFalse;
    run(["reggae", "-C", testPath, "-b", "tup", `--dflags=-g -debug`, testPath]).
        shouldThrowWithMessage("dub integration not supported with the tup backend");
}

@("dub project with prebuild command")
@Tags(["dub", "ninja"])
unittest {

    const testPath = newTestDir;
    const projPath = buildPath(origPath, "tests", "projects", "dub_prebuild");

    foreach(entry; dirEntries(projPath, SpanMode.depth)) {
        if(entry.isDir) continue;
        auto tgtName = buildPath(testPath, entry.relativePath(projPath));
        auto dir = dirName(tgtName);
        if(!dir.exists) mkdirRecurse(dir);
        copy(entry, buildPath(testPath, tgtName));
    }

    run(["reggae", "-C", testPath, "-b", "ninja", `--dflags=-g -debug`, testPath]);

    ninja.shouldExecuteOk(testPath);
    inPath(testPath, "ut").shouldExecuteOk(testPath);
}
