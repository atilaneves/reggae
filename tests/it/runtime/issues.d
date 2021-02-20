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


@ShouldFail
@("127")
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

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;

        version(Windows)
            shouldExist(`daspath\issue157.exe`);
        else
            shouldExist("daspath/issue157");
    }
}
