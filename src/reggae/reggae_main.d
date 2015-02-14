import std.stdio;
import std.process: execute;
import std.array: array, join;
import std.path: absolutePath, buildPath;
import std.typetuple;
import std.file: exists;
import std.conv: text;
import std.exception: enforce;
import reggae.options;


immutable reggaeSrcDirName = "reggae";


int main(string[] args) {
    try {

        immutable options = getOptions(args);
        enforce(options.projectPath != "", "A project path must be specified");

        immutable buildFileName = buildPath(options.projectPath, "reggaefile.d");
        enforce(buildFileName.exists, text("Could not find ", buildFileName));

        alias fileNames = TypeTuple!("run_main.d",
                                     "backend.d", "build.d",
                                     "makefile.d", "ninja.d", "options.d",
                                     "package.d", "range.d", "reflect.d",
                                     "rules.d", "dependencies.d", "rdmd.d", "config.d");
        writeSrcFiles!(fileNames);
        string[] reggaeSrcs;
        foreach(fileName; fileNames) {
            reggaeSrcs ~= reggaeSrcFileName(fileName);
        }

        immutable binName = "build";
        const compile = ["dmd", "-g", "-debug","-I" ~ options.projectPath, "-I.",
                         "-of" ~ binName,
                         buildFileName] ~ reggaeSrcs;
        immutable retComp = execute(compile);
        enforce(retComp.status == 0, text("Couldn't execute ", compile.join(" "), ":\n", retComp.output));


        immutable retRun = execute([buildPath(".",  binName), "-b", options.backend, options.projectPath]);
        enforce(retRun.status == 0, text("Couldn't execute the produced ", binName, " binary:\n", retRun.output));

    } catch(Exception ex) {
        stderr.writeln(ex.msg);
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
