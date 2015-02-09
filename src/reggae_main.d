import reggae;
import std.stdio;
import std.process: execute;
import std.array: array, join;
import std.path: absolutePath;
import std.algorithm: map;
import std.array;


int main(string[] args) {
    {
        auto file = File("tmpfile.d", "w");
        file.write(import("run_main.d"));
    }

    const projectPath = args[1];
    const reggaeSrcs = ["backend.d", "build.d", "makefile.d",
                        "package.d", "range.d", "reflect.d"].
        map!(a => "/home/aalvesne/coding/d/reggae/src/reggae/" ~ a).array;
    auto compile = ["dmd", "-g", "-debug","-I" ~ projectPath, "-I/home/aalvesne/coding/d/reggae/src",
                    "-ofbuild", "tmpfile.d",
                    buildPath(projectPath, "reggaefile.d")] ~ reggaeSrcs;
    auto retComp = execute(compile);
    if(retComp.status != 0) {
        stderr.writeln("Couldn't execute ", compile.join(" "), ":\n", retComp.output);
        return 1;
    }

    auto retRun = execute(["./build", projectPath]);
    if(retRun.status != 0) {
        stderr.writeln("Couldn't execute the produced build binary:\n", retRun.output);
        return 1;
    }

    return 0;
}
