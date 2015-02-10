import std.stdio;
import std.process: execute;
import std.array: array, join;
import std.path: absolutePath, buildPath;
import std.typetuple;
import reggae.options;


immutable reggaeSrcDirName = "reggae";


int main(string[] args) {
    alias fileNames = TypeTuple!("run_main.d",
                                 "backend.d", "build.d",
                                 "makefile.d", "options.d",
                                 "package.d", "range.d", "reflect.d");
    writeSrcFiles!(fileNames);
    string[] reggaeSrcs;
    foreach(fileName; fileNames) {
        reggaeSrcs ~= reggaeSrcFileName(fileName);
    }

    immutable options = getOptions(args);
    immutable binName = "build";
    const compile = ["dmd", "-g", "-debug","-I" ~ options.projectPath, "-I.",
                     "-of" ~ binName,
                     buildPath(options.projectPath, "reggaefile.d")] ~ reggaeSrcs;

    immutable retComp = execute(compile);
    if(retComp.status != 0) {
        stderr.writeln("Couldn't execute ", compile.join(" "), ":\n", retComp.output);
        return 1;
    }

    immutable retRun = execute([buildPath(".",  binName), "-b", options.backend, options.projectPath]);
    if(retRun.status != 0) {
        stderr.writeln("Couldn't execute the produced ", binName, " binary:\n", retRun.output);
        return 1;
    }

    return 0;
}


void writeSrcFiles(fileNames...)() {
    import std.file: mkdir;
    mkdir(reggaeSrcDirName);
    foreach(fileName; fileNames) {
        auto file = File(reggaeSrcFileName(fileName), "w");
        file.write(import(fileName));
    }
}


string reggaeSrcFileName(in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName, fileName);
}
