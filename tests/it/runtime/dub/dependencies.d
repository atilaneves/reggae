/**
   Tests for non-dub projects that use dub
*/
module tests.it.runtime.dub.dependencies;


import tests.it.runtime;


// don't ask...
version(Windows)
    alias ArghWindows = Flaky;
else
    enum ArghWindows;


// A dub package that isn't at the root of the project directory
@("dubDependant.path.exe")
@ArghWindows
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
                    DubDependantTargetType.executable,
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
@("dubDependant.path.lib")
@ArghWindows
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
                    DubDependantTargetType.staticLibrary,
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
@ArghWindows
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
                    DubDependantTargetType.sharedLibrary,
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
@ArghWindows
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
                    DubDependantTargetType.executable,
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
@ArghWindows
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
                    DubDependantTargetType.executable,
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
@ArghWindows
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
                    DubDependantTargetType.executable,
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
@ArghWindows
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
                    DubDependantTargetType.executable,
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

@("dubDependency.exe")
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
                alias dubDep = dubDependency!(DubPath("over/there"));
                mixin build!dubDep;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("foo", "0");
        shouldFail(   "foo", "1");
    }
}

@("dubDependency.lib.config")
@Tags("dub", "ninja")
unittest {
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
                alias dubDep = dubDependency!(
                    DubPath("over/there"),
                    Configuration("unittest"),
                );
                mixin build!dubDep;
            }
        );

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        shouldSucceed("ut");
    }
}
