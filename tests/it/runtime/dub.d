module tests.it.runtime.dub;


import tests.it.runtime;
import reggae.reggae;
import std.path;


@("dub project with no reggaefile ninja")
@Tags(["dub", "ninja"])
unittest {

    import std.string: join;

    with(immutable ReggaeSandbox("dub")) {
        shouldNotExist("reggaefile.d");
        writelnUt("\n\nReggae output:\n\n", runReggae("-b", "ninja", "--dflags=-g -debug").lines.join("\n"), "-----\n");
        shouldExist("reggaefile.d");
        auto output = ninja.shouldExecuteOk(testPath);
        output.shouldContain("-g -debug");

        shouldSucceed("atest").shouldEqual(
            ["Why hello!",
             "",
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
        writeFile("source/app.d", "void main() {}");

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
            mixin build!(dubTestTarget!(CompilerFlags("-g -debug")));
        });

        mkdirRecurse(buildPath(testPath, "source"));
        writeFile("source/foo.d", `unittest { assert(false); }`);
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);

        shouldFail("ut");
    }
}

@("issue #23 - reggae/dub build should rebuild if dub.json/sdl change")
@Tags(["dub", "make"])
unittest {

    import std.process: execute;
    import std.path: buildPath;

    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "make", "--dflags=-g -debug");
        make.shouldExecuteOk(testPath).shouldContain("-g -debug");
        {
            const ret = execute(["touch", buildPath(testPath, "dub.json")]);
            ret.status.shouldEqual(0);
        }
        {
            const ret = execute(["make", "-C", testPath]);
            // don't assert on the status of ret - it requires rerunning reggae
            // and that can fail if the reggae binary isn't built yet.
            // Either way -g -debug shows up in the output as the code attempts
            // to rebuild the binary
            ret.output.shouldContain("-g -debug");
        }
    }
}

@("version from main package is used in dependent packages")
@Tags(["dub", "ninja"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            versions "lefoo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            version(lefoo)
                int lebar() { return 3; }
            else
                int lebar() { return 42; }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("foo").shouldEqual(
            [
                "3",
            ]
        );
    }
}


@("sourceLibrary dependency")
@Tags(["dub", "ninja", "foo"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "foo"
            versions "lefoo"
            targetType "executable"
            dependency "bar" path="bar"
        `);
        writeFile("source/app.d", q{
            void main() {
                import bar;
                import std.stdio;
                writeln(lebar);
            }
        });
        writeFile("bar/dub.sdl", `
            name "bar"
            targetType "sourceLibrary"
        `);
        writeFile("bar/source/bar.d", q{
            module bar;
            version(lefoo)
                int lebar() { return 3; }
            else
                int lebar() { return 42; }
        });
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk(testPath);
        shouldSucceed("foo").shouldEqual(
            [
                "3",
            ]
        );
    }
}
