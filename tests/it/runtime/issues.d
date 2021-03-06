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

        version(Windows)
            enum ut = `daspath\ut.exe`;
        else
            enum ut = "daspath/ut";

        runReggae("-b", "ninja");
        ninja(["default", ut]).shouldExecuteOk;

        version(Windows) {
            shouldExist(`daspath\issue157.exe`);
            shouldExist(`daspath\ut.exe`);
        } else {
            shouldExist("daspath/issue157");
            shouldExist("daspath/ut");
        }
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
