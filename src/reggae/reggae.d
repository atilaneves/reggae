/**
 The main entry point for the reggae tool. Its tasks are:
 $(UL
   $(LI Verify that a $(D reggafile.d) exists in the selected directory)
   $(LI Generate a $(D reggaefile.d) for dub projects)
   $(LI Write out the reggae library files and $(D config.d))
   $(LI Compile the build description with the reggae library files to produce $(D buildgen))
   $(LI Produce $(D dcompile), a binary to call the D compiler to obtain dependencies during compilation)
   $(LI Call the produced $(D buildgen) binary)
 )
 */


module reggae.reggae;

import std.stdio;
import std.process: execute;
import std.array: array, join, empty;
import std.path: absolutePath, buildPath, relativePath;
import std.typetuple;
import std.file: exists;
import std.conv: text;
import std.exception: enforce;
import std.conv: to;
import std.algorithm;

import reggae.options;
import reggae.ctaa;


version(minimal) {
    //empty stubs for minimal version of reggae
    void maybeCreateReggaefile(T...)(T) {}
    void writeDubConfig(T...)(T) {}
} else {
    import reggae.dub.interop;
}

mixin template reggaeGen(targets...) {
    mixin buildImpl!targets;
    mixin ReggaeMain;
}

mixin template ReggaeMain() {
    import reggae.options: getOptions;
    import std.stdio: stderr;

    int main(string[] args) {
        try {
            run(getOptions(args));
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void run(in Options options) {
    if(options.help) return;
    enforce(options.projectPath != "", "A project path must be specified");

    maybeCreateReggaefile(options);
    createBuild(options);
}


enum coreFiles = [
    "buildgen_main.d", "buildgen.d",
    "build.d",
    "backend/binary.d",
    "package.d", "range.d", "reflect.d",
    "dependencies.d", "types.d", "dcompile.d",
    "ctaa.d", "sorting.d",
    "rules/package.d",
    "rules/common.d",
    "rules/d.d",
    "core/package.d", "core/rules/package.d",
    ];
enum otherFiles = [
    "backend/ninja.d", "backend/make.d",
    "dub/info.d", "rules/dub.d",
    ];

//all files that need to be written out and compiled
private string[] fileNames() @safe pure nothrow {
    version(minimal) return coreFiles;
    else return coreFiles ~ otherFiles;
}


private void createBuild(in Options options) {

    immutable reggaefilePath = getReggaefilePath(options);
    enforce(reggaefilePath.exists, text("Could not find ", reggaefilePath));

    //write out the library source files to be compiled with the user's
    //build description
    writeSrcFiles(options);

    //compile the binaries (the build generator and dcompile)
    immutable buildGenName = compileBinaries(options);

    //actually run the build generator
    writeln("[Reggae] Running the created binary to generate the build");
    immutable retRunBuildgen = execute([buildPath(".", buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));

    writeln(retRunBuildgen.output);
}

private immutable hiddenDir = ".reggae";


private auto compileBinaries(in Options options) {
    immutable buildGenName = getBuildGenName(options);
    const compileBuildGenCmd = getCompileBuildGenCmd(options);

    immutable dcompileName = buildPath(hiddenDir, "dcompile");
    immutable dcompileCmd = ["dmd",
                             "-I.reggae/src",
                             "-of" ~ dcompileName,
                             reggaeSrcFileName("dcompile.d"),
                             reggaeSrcFileName("dependencies.d")];


    static struct Binary { string name; const(string)[] cmd; }

    const binaries = [Binary(buildGenName, compileBuildGenCmd), Binary(dcompileName, dcompileCmd)];
    import std.parallelism;

    foreach(bin; binaries.parallel) {
        writeln("[Reggae] Compiling metabuild binary ", bin.name);
        immutable res = execute(bin.cmd);
        enforce(res.status == 0, text("Couldn't execute ", bin.cmd.join(" "), ":\n", res.output,
                                      "\n", "bin.name: ", bin.name, ", bin.cmd: ", bin.cmd.join(" ")));
    }

    return buildGenName;
}

string[] getCompileBuildGenCmd(in Options options) @safe nothrow {
    const reggaeSrcs = ("config.d" ~ fileNames).
        filter!(a => a != "dcompile.d").
        map!(a => a.reggaeSrcFileName).array;

    immutable buildBinFlags = options.backend == Backend.binary
        ? ["-O", "-release", "-inline"]
        : [];
    immutable commonBefore = ["dmd",
                              "-I" ~ options.projectPath,
                              "-g", "-debug",
                              "-of" ~ getBuildGenName(options)];
    const commonAfter = buildBinFlags ~ reggaeSrcs ~ getReggaefilePath(options);
    version(minimal) return commonBefore ~ "-version=minimal" ~ commonAfter;
    else return commonBefore ~ commonAfter;
}

string getBuildGenName(in Options options) @safe pure nothrow {
    return options.backend == Backend.binary ? "build" : buildPath(hiddenDir, "buildgen");
}

immutable reggaeSrcDirName = buildPath(".reggae", "src", "reggae");

private string filesTupleString() @safe pure nothrow {
    return "TypeTuple!(" ~ fileNames.map!(a => `"` ~ a ~ `"`).join(",") ~ ")";
}

template FileNames() {
    mixin("alias FileNames = " ~ filesTupleString ~ ";");
}


private void writeSrcFiles(in Options options) {
    import std.file: mkdirRecurse;
    if(!reggaeSrcDirName.exists) {
        mkdirRecurse(reggaeSrcDirName);
        mkdirRecurse(buildPath(reggaeSrcDirName, "dub"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "rules"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "backend"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "core", "rules"));
    }


    //this foreach has to happen at compile time due
    //to the string import below.
    foreach(fileName; FileNames!()) {
        auto file = File(reggaeSrcFileName(fileName), "w");
        file.write(import(fileName));
    }

    writeConfig(options);
}


private void writeConfig(in Options options) {
    auto file = File(reggaeSrcFileName("config.d"), "w");

    file.writeln(q{
        module reggae.config;
        import reggae.ctaa;
        import reggae.types: Backend;

    });

    file.writeln("enum projectPath = `", options.projectPath, "`;");
    file.writeln("enum backend = Backend.", options.backend, ";");
    file.writeln("enum dflags = `", options.dflags, "`;");
    file.writeln("enum reggaePath = `", options.reggaePath, "`;");
    file.writeln("enum buildFilePath = `", options.getReggaefilePath.absolutePath, "`;");
    file.writeln("enum cCompiler = `", options.cCompiler, "`;");
    file.writeln("enum cppCompiler = `", options.cppCompiler, "`;");
    file.writeln("enum dCompiler = `", options.dCompiler, "`;");
    file.writeln("enum perModule = ", options.perModule, ";");

    file.writeln("enum userVars = AssocList!(string, string)([");
    foreach(key, value; options.userVars) {
        file.writeln("assocEntry(`", key, "`, `", value, "`), ");
    }
    file.writeln("]);");

    writeDubConfig(options, file);
}



private string reggaeSrcFileName(in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName, fileName);
}

private string getReggaefilePath(in Options options) @safe nothrow {
    immutable regular = projectBuildFile(options);
    if(regular.exists) return regular;
    immutable path = options.isDubProject ? "" : options.projectPath;
    return buildPath(path, "reggaefile.d");
}
