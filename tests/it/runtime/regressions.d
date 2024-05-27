module tests.it.runtime.regressions;


import tests.it.runtime;
import reggae.reggae;


@("Issue 14: builddir not expanded")
@Tags(["ninja", "regressions", "posix"])
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.d", q{
            import reggae;
            enum ao = objectFile!(SourceFile("a.c"));
            enum liba = Target("$builddir/liba.a", "ar rcs $out $in", [ao]);
            mixin build!(liba);
        });

        writeFile("a.c");

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}

@("Issue 12: can't set executable as a dependency")
@Tags(["ninja", "regressions"])
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("reggaefile.d", q{
            import reggae;
            alias app = scriptlike!(App(SourceFileName("main.d"),
                                        BinaryFileName("$builddir/myapp")),
                                        Flags(),
                                        ImportPaths(["/path/to/imports"])
                    );
            alias code_gen = target!("out.c", "./myapp $in $out", target!"in.txt", app);
            mixin build!(code_gen);
        });

        writeFile("main.d", q{
            import std.stdio;
            import std.algorithm;
            import std.conv;
            void main(string[] args) {
                auto inFileName = args[1];
                auto outFileName = args[2];
                auto lines = File(inFileName, `r`).byLine.
                    map!(a => a.to!string).
                    map!(a => a ~ ` ` ~ a);
                auto outFile = File(outFileName, `w`);
                foreach(line; lines) outFile.writeln(line);
            }
        });

        writeFile("in.txt", ["foo", "bar", "baz"]);

        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
        ["cat", "out.c"].shouldExecuteOk;
        shouldEqualLines("out.c",
                         ["foo foo",
                          "bar bar",
                          "baz baz"]);
    }
}


@("Issue 10: dubConfigurationTarget doesn't work for unittest builds")
@Tags(["ninja", "regressions"])
unittest {
    import reggae.path: buildPath;
    import std.file;

    with(immutable ReggaeSandbox()) {

        writeFile("dub.json", `
            {
                "name": "dubproj",
                "configurations": [
                    { "name": "executable", "targetName": "foo"},
                    { "name": "unittest", "targetName": "ut"}
              ]
            }`);

        writeFile("reggaefile.d", q{
            import reggae;
            alias ut = dubBuild!(Configuration(`unittest`));
            mixin build!ut;
        });

        mkdir(buildPath(testPath, "source"));
        writeFile(buildPath("source/src.d"), q{
            unittest { static assert(false, `oopsie`); }
            int add(int i, int j) { return i + j; }
        });

        writeFile(buildPath("source/main.d"), q{
            import src;
            void main() {}
        });

        runReggae("-b", "ninja");
        ninja.shouldFailToExecute(testPath);
    }
}

@("buildgen.binary")
@Tags("binary")
unittest {
    import reggae.rules.common: exeExt;
    with(immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias lib = staticLibrary!("mylib", Sources!("src"));
                mixin build!lib;
            }
        );

        writeFile("src/foo.d", "void foo() {}");
        runReggae("-b", "binary");
        shouldExist("build" ~ exeExt);
    }
}
