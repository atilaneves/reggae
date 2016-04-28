module tests.it.runtime.regressions;


import tests.it.runtime;
import reggae.reggae;
import std.path;


@("Issue 14: builddir not expanded")
@Tags(["ninja", "regressions"])
unittest {
    import std.stdio;
    const testPath = newTestDir;
    {
        File(buildPath(testPath, "reggaefile.d"), "w").writeln(q{
            import reggae;
            enum ao = objectFile(SourceFile("a.c"));
            enum liba = Target("$builddir/liba.a", "ar rcs $out $in", [ao]);
            mixin build!(liba);
        });

        File(buildPath(testPath, "a.c"), "w").writeln;
    }

    testRun(["reggae", "-C", testPath, "-b", "ninja", testPath]);
    ninja.shouldExecuteOk(testPath);
}

@("Issue 12: can't set executable as a dependency")
@Tags(["ninja", "regressions"])
unittest {
    import std.stdio;
    import std.file;
    import std.string;

    const testPath = newTestDir;
    {
        File(buildPath(testPath, "reggaefile.d"), "w").writeln(q{
            import reggae;
            alias app = scriptlike!(App(SourceFileName("main.d"),
                                        BinaryFileName("$builddir/myapp")),
                                        Flags("-g -debug"),
                                        ImportPaths(["/path/to/imports"])
                    );
            alias code_gen = target!("out.c", "./myapp $in $out", target!"in.txt", app);
            mixin build!(code_gen);
        });

        File(buildPath(testPath, "main.d"), "w").writeln(q{
            import std.stdio;
            import std.algorithm;
            import std.conv;
            void main(string[] args) {
                auto inFileName = args[1];
                auto outFileName = args[2];
                auto lines = File(inFileName).byLine.
                    map!(a => a.to!string).
                    map!(a => a ~ ` ` ~ a);
                auto outFile = File(outFileName, `w`);
                foreach(line; lines) outFile.writeln(line);
            }
        });

        auto f = File(buildPath(testPath, "in.txt"), "w");
        f.writeln("foo");
        f.writeln("bar");
        f.writeln("baz");
    }

    testRun(["reggae", "-C", testPath, "-b", "ninja", testPath]);
    ninja.shouldExecuteOk(testPath);
    ["cat", "out.c"].shouldExecuteOk(testPath);
    readText(buildPath(testPath, "out.c")).chomp.split("\n").shouldEqual(
        ["foo foo",
         "bar bar",
         "baz baz"]);
}
