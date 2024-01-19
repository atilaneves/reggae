/**
   Tests for non-dub projects that use dub
*/
module tests.it.runtime.dub.dependencies;


import tests.it.runtime;


version(Windows)
    alias MaybeFlaky = Flaky;
else version(LDC)
    alias MaybeFlaky = Flaky;
else
    enum MaybeFlaky;


// A dub package that isn't at the root of the project directory
@("dubDependant.path.exe.default")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    import reggae.rules.common: exeExt;
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile(
            "over/there/source/foo.d",
            q{int twice(int i) { return i * 2; }}
        );
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() {
                    assert(5.twice == 10);
                }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.executable,
                    Sources!(Files("src/app.d")),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldExist("myapp" ~ exeExt);
        shouldSucceed("myapp");
    }
}

// A dub package that isn't at the root of the project directory
@("dubDependant.path.exe.config")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    import reggae.rules.common: exeExt;
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`,
                `configuration "default" {`,
                `}`,
                `configuration "weirdo" {`,
                `    versions "weird"`,
                `}`,
            ]
        );
        // src code for the dub dependency
        writeFile(
            "over/there/source/foo.d",
            q{
                int result(int i) {
                    version(weird)
                        return i * 3;
                    else
                        return i * 2;
                }
            }
        );
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() {
                    assert(5.result == 15);
                    assert(6.result == 18);
                }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.executable,
                    Sources!(Files("src/app.d")),
                    DubPath("over/there", Configuration("weirdo")),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldExist("myapp" ~ exeExt);
        shouldSucceed("myapp");
    }
}


// A dub package that isn't at the root of the project directory
@("dubDependant.path.lib")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    import reggae.rules.common: libExt;
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile(
            "over/there/source/foo.d",
            q{int twice(int i) { return i * 2; }}
        );
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() {
                    assert(5.twice == 10);
                }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.staticLibrary,
                    Sources!(Files("src/app.d")),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldExist("myapp" ~ libExt);
        version(Posix)
            ["file", inSandboxPath("myapp" ~ libExt)]
                .shouldExecuteOk
                .shouldContain("archive");
    }
}

// A dub package that isn't at the root of the project directory
@("dubDependant.path.dll")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    import reggae.rules.common: dynExt;
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile(
            "over/there/source/foo.d",
            q{int twice(int i) { return i * 2; }}
        );
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() {
                    assert(5.twice == 10);
                }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.sharedLibrary,
                    Sources!(Files("src/app.d")),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldExist("myapp" ~ dynExt);
        version(Posix)
            ["file", inSandboxPath("myapp" ~ dynExt)]
                .shouldExecuteOk
                .shouldContain("shared");
    }
}

@("dubDependant.flags.compiler")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile("over/there/source/foo.d", "");
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() { }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.executable,
                    Sources!(Files("src/app.d")),
                    CompilerFlags("-foo", "-bar"),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        fileShouldContain("build.ninja", "flags = -foo -bar");
    }
}


@("dubDependant.flags.linker")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile("over/there/source/foo.d", "");
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() { }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.executable,
                    Sources!(Files("src/app.d")),
                    CompilerFlags("-abc", "-def"),
                    LinkerFlags("-quux"),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        fileShouldContain("build.ninja", "flags = -quux");
    }
}


@("dubDependant.flags.imports")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile("over/there/source/foo.d", "");
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() { }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.executable,
                    Sources!(Files("src/app.d")),
                    ImportPaths("leimports"),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        fileShouldContain("build.ninja", "-I" ~ inSandboxPath("leimports"));
    }
}


@("dubDependant.flags.stringImports")
@MaybeFlaky
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        // a dub package we're going to depend on by path
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`
            ]
        );
        // src code for the dub dependency
        writeFile("over/there/source/foo.d", "");
        // our main program, which will depend on a dub package by path
        writeFile(
            "src/app.d",
            q{
                import foo;
                void main() { }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias app = dubDependant!(
                    TargetName("myapp"),
                    DubPackageTargetType.executable,
                    Sources!(Files("src/app.d")),
                    StringImportPaths("lestrings"),
                    DubPath("over/there"),
                );
                mixin build!app;
            }
        );

        runReggae("-b", "ninja");
        fileShouldContain("build.ninja", "-J" ~ inSandboxPath("lestrings"));
    }
}

@("dubPackage.exe.naked")
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "executable"`,
            ]
       );
        writeFile(
            "over/there/source/app.d",
            q{
                int main(string[] args) {
                    import std.conv: to;
                    return args[1].to!int;
                }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias dubDep = dubPackage!(DubPath("over/there"));
                mixin build!dubDep;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("over/there/foo", "0");
        shouldFail(   "over/there/foo", "1");
    }
}

@("dubPackage.exe.phony")
@Tags("dub", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "executable"`,
            ]
       );
        writeFile(
            "over/there/source/app.d",
            q{
                int main(string[] args) {
                    import std.conv: to;
                    return args[1].to!int;
                }
            }
        );
        writeFile(
            "reggaefile.d",
            q{
                import reggae;

                alias dubDep = dubPackage!(DubPath("over/there"));
                alias yay = phony!("yay", dubDep, ["0"]);
                alias nay = phony!("nay", dubDep, ["1"]);
                mixin build!(yay, nay);
            }
        );

        runReggae("-b", "ninja");
        ninja(["yay"]).shouldExecuteOk;
        ninja(["nay"]).shouldFailToExecute;
    }
}


@("dubPackage.lib.config")
@Tags("dub", "ninja")
unittest {
    import reggae.rules.common: exeExt;
    with(immutable ReggaeSandbox()) {
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`,
                `configuration "default" {`,
                `}`,
                `configuration "unittest" {`,
                `    targetName "ut"`,
                `    targetPath "bin"`,
                `    mainSourceFile "ut_main.d"`,
                `}`,
            ]
       );
        writeFile("over/there/source/foo.d", "");
        writeFile("over/there/ut_main.d", "void main() {}");
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias dubDep = dubPackage!(
                    DubPath("over/there", Configuration("unittest")),
                );
                mixin build!dubDep;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("over/there/bin/ut" ~ exeExt);
    }
}

@HiddenTest
@("dubPackage.lib.timing")
@Tags("dub", "ninja")
unittest {
    import reggae.rules.common: exeExt;
    import std.datetime.stopwatch;

    with(immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias dubDep = dubPackage!(DubPath("over/there"));
                mixin build!dubDep;
            }
        );
        writeFile(
            "over/there/dub.sdl",
            [
                `name "foo"`,
                `targetType "library"`,
            ]
       );
        writeFile("over/there/source/foo.d", "");

        auto sw = StopWatch(AutoStart.yes);
        runReggae("-b", "ninja");
        auto dur1 = cast(Duration) sw.peek;
        sw.reset;

        runReggae("-b", "ninja");
        auto dur2 = cast(Duration) sw.peek;

        // should take far less time the 2nd time around (no compiling)
        dur2.shouldBeSmallerThan(dur1 / 2);
    }
}
