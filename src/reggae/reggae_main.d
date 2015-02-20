import std.stdio;
import std.process: execute;
import std.array: array, join;
import std.path: absolutePath, buildPath;
import std.typetuple;
import std.file: exists;
import std.conv: text;
import std.exception: enforce;
import reggae.options;


immutable reggaeSrcDirName = buildPath(".reggae", "src", "reggae");


int main(string[] args) {
    try {
        immutable options = getOptions(args);
        enforce(options.projectPath != "", "A project path must be specified");
        createBuild(options);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}

void createBuild(in Options options) {

    immutable buildFileName = buildPath(options.projectPath, "reggaefile.d");
    enforce(buildFileName.exists, text("Could not find ", buildFileName));

    alias fileNames = TypeTuple!("buildgen_main.d",
                                 "build.d",
                                 "makefile.d", "ninja.d", "options.d",
                                 "package.d", "range.d", "reflect.d",
                                 "rules.d", "dependencies.d", "types.d",
                                 "dub.d");
    writeSrcFiles!(fileNames)(options);
    string[] reggaeSrcs = [reggaeSrcFileName("config.d")];
    foreach(fileName; fileNames) {
        reggaeSrcs ~= reggaeSrcFileName(fileName);
    }

    immutable binName = "buildgen";
    const compile = ["dmd", "-g", "-debug","-I" ~ options.projectPath,
                     "-of" ~ binName] ~ reggaeSrcs ~ buildFileName;

    immutable retCompBuildgen = execute(compile);
    enforce(retCompBuildgen.status == 0,
            text("Couldn't execute ", compile.join(" "), ":\n", retCompBuildgen.output));

    immutable retRunBuildgen = execute([buildPath(".",  binName), "-b", options.backend, options.projectPath]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", binName, " binary:\n", retRunBuildgen.output));

    immutable retCompDcompile = execute(["dmd",
                                         reggaeSrcFileName("dcompile.d"),
                                         reggaeSrcFileName("dependencies.d")]);
    enforce(retCompDcompile.status == 0, text("Couldn't compile dcompile.d:\n", retCompDcompile.output));

}


void writeSrcFiles(fileNames...)(in Options options) {
    import std.file: mkdirRecurse;
    if(!reggaeSrcDirName.exists) mkdirRecurse(reggaeSrcDirName);

    foreach(fileName; fileNames) {
        auto file = File(reggaeSrcFileName(fileName), "w");
        file.write(import(fileName));
    }
    {
        auto file = File(reggaeSrcFileName("dcompile.d"), "w");
        file.write(import("dcompile.d"));
    }
    {
        auto file = File(reggaeSrcFileName("config.d"), "w");
        file.writeln("module reggae.config;");
        file.writeln("immutable projectPath = `", options.projectPath, "`;");
    }
}


string reggaeSrcFileName(in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName, fileName);
}
