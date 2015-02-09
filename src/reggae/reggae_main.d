import reggae;
import std.stdio;
import std.process: execute;
import std.array: array, join;
import std.path: absolutePath;
import std.typetuple;


int main(string[] args) {
    alias fileNames = TypeTuple!("run_main.d", "backend.d", "build.d",
                                 "makefile.d",
                                 "package.d", "range.d", "reflect.d");
    writeSrcFiles!(fileNames);
    string[] reggaeSrcs;
    foreach(fileName; fileNames) {
        reggaeSrcs ~= fileName;
    }

    const projectPath = args[1];
    auto compile = ["dmd", "-g", "-debug","-I" ~ projectPath, "-I.",
                    "-ofbuild",
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


void writeSrcFiles(fileNames...)() {
    foreach(fileName; fileNames) {
        auto file = File(fileName, "w");
        file.write(import(fileName));
    }
}
