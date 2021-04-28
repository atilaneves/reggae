module tests.it.runtime.issues;


import tests.it.runtime;


// reggae/dub build should rebuild if dub.json/sdl change
@("23")
@Tags(["dub", "make"])
unittest {

    import std.process: execute;
    import reggae.path: buildPath;

    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "make", "--dflags=-g -debug");
        make(["VERBOSE=1"]).shouldExecuteOk.shouldContain("-g -debug");
        {
            const ret = execute(["touch", buildPath(testPath, "dub.json")]);
            ret.status.shouldEqual(0);
        }
        {
            const ret = execute(["make", "-C", testPath]);
            // don't assert on the status of ret - it requires rerunning reggae
            // and that can fail if the reggae binary isn't built yet.
            // Either way make should run
            ret.output.shouldNotContain("Nothing to be done");
        }
    }
}


@("62")
@Tags(["dub", "make"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "issue62"
            dependency "arsd-official:nanovega" version="*"
        `);
        writeFile("source/app.d", q{
                import arsd.simpledisplay;
                import arsd.nanovega;
                void main () { }
            }
        );
        runReggae("-b", "make");
        make.shouldExecuteOk;
        shouldSucceed("issue62");
    }
}


@("dubLink")
@Tags(["dub", "make"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "dublink"
        `);
        writeFile("source/app.d", q{
                void main () { }
            }
        );
        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias sourceObjs = dlangObjects!(Sources!"source");
                      alias exe = dubLink!(TargetName("exe"), Configuration("default"), sourceObjs);
                      mixin build!exe;
                  });
        runReggae("-b", "make");
        make.shouldExecuteOk;
        shouldSucceed("exe");
    }
}


@("127.0")
@Tags("dub", "issues", "ninja")
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue157"`,
                `targetType "executable"`,
                `targetPath "daspath"`
            ]
        );

        writeFile("source/app.d",
            [
                `void main() {}`,
            ]
        );

        version(Windows) {
            enum ut = `daspath\ut.exe`;
            enum bin = `daspath\issue157.exe`;
        } else {
            enum ut = "daspath/ut";
            enum bin = "daspath/issue157";
        }

        runReggae("-b", "ninja");
        ninja(["default", ut]).shouldExecuteOk;

        shouldExist(bin);
        shouldExist(ut);
    }
}


@("127.1")
@Tags("dub", "issues", "ninja")
unittest {

    import std.file: mkdir;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue157"`,
                `targetType "executable"`,
                `targetPath "daspath"`
            ]
        );

        writeFile("source/app.d",
            [
                `void main() {}`,
            ]
        );

        const bin = inSandboxPath("bin");
        mkdir(bin);
        runReggae("-C", bin, "-b", "ninja", testPath);
        ninja(["-C", bin, "default", "ut"]).shouldExecuteOk;

        version(Windows) {
            shouldExist(`bin\issue157.exe`);
            shouldExist(`bin\ut.exe`);
        } else {
            shouldExist("bin/issue157");
            shouldExist("bin/ut");
        }
    }
}


@("140")
@Tags("dub", "issues", "ninja")
unittest {

    import std.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue140"`,
                `targetType "executable"`,
                `targetPath "daspath"`,
                `dependency "bar" path="bar"`
            ]
        );

        writeFile("source/app.d",
            [
                `void main() {}`,
            ]
        );

        writeFile(
            "bar/dub.sdl",
            [
                `name "bar"`,
                `copyFiles "$PACKAGE_DIR/txts/text.txt"`
            ]
        );
        writeFile("bar/source/bar.d",
            [
                `module bar;`,
                `int twice(int i) { return i * 2; }`,
            ]
        );

        writeFile("bar/txts/text.txt", "das text");

        runReggae("-b", "ninja");
        ninja(["default"]).shouldExecuteOk;
        shouldExist(buildPath("daspath", "text.txt"));
    }
}


@("144")
@Tags("dub", "issues", "ninja")
unittest {

    import std.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue144"`,
                `targetType "executable"`,
                `configuration "default" {`,
                `}`,
                `configuration "daslib" {`,
                `    targetType "library"`,
                `    excludedSourceFiles "source/main.d"`,
                `}`,
                `configuration "weird" {`,
                `    targetName "weird"`,
                `    versions "weird"`,
                `}`,
            ]
        );

        writeFile("source/main.d",
            [
                `void main() {}`,
            ]
        );

        writeFile("source/lib.d",
            [
                `int twice(int i) { return i * 2; }`,
            ]
        );

        version(Windows) {
            enum exe = "issue144.exe";
            enum lib = "issue144.lib";
            enum ut  = "ut.exe";
        } else {
            enum exe = "issue144";
            enum lib = "issue144.a";
            enum ut  = "ut";
        }

        runReggae("-b", "ninja", "--dub-config=daslib");

        ninja([lib]).shouldExecuteOk;
        ninja([exe]).shouldFailToExecute.should ==
            ["ninja: error: unknown target '" ~ exe ~ "', did you mean '" ~ lib ~ "'?"];
        // No unittest target when --dub-config is used
        ninja([ut]).shouldFailToExecute.should ==
            ["ninja: error: unknown target '" ~ ut ~ "'"];
    }
}
