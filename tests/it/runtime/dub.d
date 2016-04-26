module tests.it.runtime.dub;


import tests.it;
import tests.utils;
import reggae.reggae;
import std.path;
import std.file;
import std.algorithm;


@Tags("dub")
@("dub project with no reggaefile") unittest {
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
    run(["reggae", "-C", testPath, "-b", "ninja", `--dflags=-g -debug`, projPath]);
    buildPath(testPath, "reggaefile.d").exists.shouldBeTrue;

    auto output = ninja.shouldExecuteOk(testPath);
    output.canFind!(a => a.canFind("-g -debug")).shouldBeTrue;
}
