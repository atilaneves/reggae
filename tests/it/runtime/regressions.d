module tests.it.runtime.regressions;


import tests.it.runtime;
import reggae.reggae;
import std.path;


@("Recursive sub dependencies")
@Tags(["dub", "ninja", "regressions"])
unittest {
    import std.stdio;
    const testPath = newTestDir;

    {
        File(buildPath(testPath, "dub.json"), "w").writeln(`
{
    "targetType": "executable",
    "name": "simpleshader",
    "mainSourceFile": "simpleshader.d",

    "dependencies":
    {
        "gfm:sdl2": "*",
        "gfm:opengl": "*",
        "gfm:logger": "*"
    }
}`);

        File(buildPath(testPath, "simpleshader.d"), "w").writeln(q{
                import std.math, std.random, std.typecons;
                import std.experimental.logger;
                import derelict.util.loader;
                import gfm.logger, gfm.sdl2, gfm.opengl, gfm.math;
                void main() {}
        });
    }

    testRun(["reggae", "-C", testPath, "-b", "ninja"]);
    ninja.shouldExecuteOk(testPath);
}


@("Issue 14: builddir not expanded")
@Tags(["ninja", "regressions"])
unittest {
    import std.stdio;
    const testPath = newTestDir;
    {
        File(buildPath(testPath, "simpleshader.d"), "w").writeln(q{
            import reggae;
            enum ao = objectFile(SourceFile("a.c"));
            enum liba = Target("$builddir/liba.a", "ar rcs $out $in", [ao]);
            mixin build!(liba);
        });
    }

    testRun(["reggae", "-C", testPath, "-b", "ninja"]);
    ninja.shouldExecuteOk(testPath);
}
