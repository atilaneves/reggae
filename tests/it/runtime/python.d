/**
  As a reggae user
  I want to be able to write build descriptions in Python
  So I don't have to compile the build description
 */

module tests.it.runtime.python;

import tests.it.runtime;

@("Build description in Python")
@Tags(["ninja", "json_build"])
unittest {
    import std.stdio;
    import std.path;

    const testPath = newTestDir;
    {
        File(buildPath(testPath, "reggaefile.py"), "w").writeln(`
            from reggae import *
            b = Build(executable(name='app', src_dirs=['src']))
        `);
    }

    writeHelloWorldApp(testPath);

    testRun(["reggae", "-C", testPath, "-b", "ninja", testPath]);
    ninja.shouldExecuteOk(testPath);
    buildPath(testPath, "app").shouldExecuteOk(testPath).shouldEqual(
        ["Hello world!"]);
}
