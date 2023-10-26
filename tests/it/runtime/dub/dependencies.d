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
