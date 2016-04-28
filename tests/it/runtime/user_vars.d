module tests.it.runtime.user_vars;

import tests.it.runtime;
import std.file;


private void prepareBuild(in string testPath) {
    import std.stdio;
    import std.path;

    File(buildPath(testPath, "reggaefile.d"), "w").writeln(q{
        import reggae;
        static if(userVars.get("1st", false))
            mixin build!(Target("1st.txt", "touch $out"));
        else
            mixin build!(Target("2nd.txt", "touch $out"));
    });
}

@("user variables should be available when none were passed")
@Tags("make")
unittest {
    const testPath = newTestDir;
    prepareBuild(testPath);

    testRun(["reggae", "-C", testPath, "-b", "make", testPath]);
    make.shouldExecuteOk(testPath);

    // no option passed, static if failed and 2nd was "built"
    buildPath(testPath, "1st.txt").exists.shouldBeFalse;
    buildPath(testPath, "2nd.txt").exists.shouldBeTrue;
}


@("user variables should be available when they were passed")
@Tags("make")
unittest {
    const testPath = newTestDir;
    prepareBuild(testPath);

    testRun(["reggae", "-C", testPath, "-b", "make", "-d", "1st=true", testPath]);
    make.shouldExecuteOk(testPath);

    // option passed, static if succeeds and 1st was "built"
    buildPath(testPath, "1st.txt").exists.shouldBeTrue;
    buildPath(testPath, "2nd.txt").exists.shouldBeFalse;
}
