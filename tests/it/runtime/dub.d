module tests.it.runtime.dub;


import tests.it.runtime;
import reggae.reggae;
import std.path;


@("dub project with no reggaefile ninja")
@Tags(["dub", "ninja"])
unittest {

    with(immutable ReggaeSandbox("dub")) {
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
    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "tup", "--dflags=-g -debug").
            shouldThrowWithMessage("dub integration not supported with the tup backend");
    }
}

@("dub project with no reggaefile and prebuild command")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox("dub_prebuild")) {
        runReggae("-b", "ninja", "--dflags=-g -debug");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("ut");
    }
}

@("dub project with postbuild command")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox("dub_postbuild")) {
        runReggae("-b", "ninja", "--dflags=-g -debug");
        ninja.shouldExecuteOk(testPath);
        shouldExist("foo.txt");
        shouldSucceed("postbuild");
    }
}



@("project with dependencies not on file system already no dub.selections.json")
@Tags(["dub", "ninja"])
unittest {

    import std.file: exists, rmdirRecurse;
    import std.process: environment;
    import std.path: buildPath;

    const cerealedDir = buildPath(environment["HOME"], ".dub/packages/cerealed-0.6.8");
    if(cerealedDir.exists)
        rmdirRecurse(cerealedDir);

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
{
  "name": "depends_on_cerealed",
  "license": "MIT",
  "targetType": "executable",
  "dependencies": { "cerealed": "==0.6.8" }
}`);

        runReggae("-b", "ninja");
    }
}

@("project with dependencies not on file system already with dub.selections.json")
@Tags(["dub", "ninja"])
unittest {

    import std.file: exists, rmdirRecurse;
    import std.process: environment;
    import std.path: buildPath;

    const cerealedDir = buildPath(environment["HOME"], ".dub/packages/cerealed-0.6.8");
    if(cerealedDir.exists)
        rmdirRecurse(cerealedDir);

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
{
  "name": "depends_on_cerealed",
  "license": "MIT",
  "targetType": "executable",
  "dependencies": { "cerealed": "==0.6.8" }
}`);

        writeFile("dub.selections.json", `
{
        "fileVersion": 1,
        "versions": {
                "cerealed": "0.6.8",
        }
}
`);

        runReggae("-b", "ninja");
    }
}

@("simple dub project with no main function but with unit tests")
@Tags(["dub", "ninja"])
unittest {
    import std.file: mkdirRecurse;
    import std.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.json", `
            {
              "name": "depends_on_cerealed",
              "license": "MIT",
              "targetType": "executable",
              "dependencies": { "cerealed": "==0.6.8" }
            }`);

        writeFile("reggaefile.d", q{
            import reggae;
            mixin build!(dubTestTarget!(Flags("-g -debug")));
        });

        mkdirRecurse(buildPath(testPath, "source"));
        writeFile("source/foo.d", `unittest { assert(false); }`);
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);

        shouldFail("ut");
    }
}
