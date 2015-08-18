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
import std.file;
import std.conv: text;
import std.exception: enforce;
import std.conv: to;
import std.algorithm;

import reggae.options;
import reggae.ctaa;
import reggae.types;


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

    immutable pythonFile = buildPath(options.projectPath, "reggaefile.py");
    if(pythonFile.exists) {
        python(options);
        return;
    }

    maybeCreateReggaefile(options);
    createBuild(options);
}

void python(in Options options) {
    writeln("options reggaefilepath: ", options.reggaeFilePath);
    immutable pythonArgs = ["python", "-m", "reggae.json", options.projectPath];
    immutable res = execute(pythonArgs);
    enforce(res.status == 0, text("Could not execute ", pythonArgs.join(" "), ":\n", res.output));

    import reggae.json_build;
    //import reggae.buildgen;
    //generateBuild(jsonToBuild(res.output), options.args.dup);
    generateBuild(jsonToBuild(res.output), options);
}
import reggae.build;
import reggae.backend.ninja;
import reggae.backend.make;
import reggae.backend.binary;
import reggae.backend.tup;
void generateBuild(in Build build, in Options options) {
    final switch(options.backend) with(Backend) {

        case make:
            handleMake(build, options);
            break;

        case ninja:
            handleNinja(build, options);
            break;

        case tup:
            handleTup(build, options);
            break;

        case binary:
            Binary(build, options.projectPath).run(options.args.dup);
            break;

        case none:
            throw new Exception("A backend must be specified with -b/--backend");
        }
}

private void handleNinja(in Build build, in Options options) {
    version(minimal) {
        throw new Exception("Ninja backend support not compiled in");
    } else {

        const ninja = Ninja(build, options);

        auto buildNinja = File("build.ninja", "w");
        buildNinja.writeln("include rules.ninja\n");
        buildNinja.writeln(ninja.buildOutput);

        auto rulesNinja = File("rules.ninja", "w");
        rulesNinja.writeln(ninja.rulesOutput);
    }
}


private void handleMake(in Build build, in Options options) {
    version(minimal) {
        throw new Exception("Make backend support not compiled in");
    } else {

        const makefile = Makefile(build, options);
        auto file = File(makefile.fileName, "w");
        file.write(makefile.output);
    }
}

private void handleTup(in Build build, in Options options) {
    version(minimal) {
        throw new Exception("Tup backend support not compiled in");
    } else {
        if(!".tup".exists) execute(["tup", "init"]);
        const tup = Tup(build, options.projectPath);
        auto file = File(tup.fileName, "w");
        file.write(tup.output);
    }
}

enum coreFiles = [
    "options.d",
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
    "backend/ninja.d", "backend/make.d", "backend/tup.d",
    "dub/info.d", "rules/dub.d",
    ];

//all files that need to be written out and compiled
private string[] fileNames() @safe pure nothrow {
    version(minimal) return coreFiles;
    else return coreFiles ~ otherFiles;
}


private void createBuild(in Options options) {

    immutable reggaefilePath = options.reggaeFilePath;
    enforce(reggaefilePath.exists, text("Could not find ", reggaefilePath));

    //write out the library source files to be compiled with the user's
    //build description
    writeSrcFiles(options);

    //compile the binaries (the build generator and dcompile)
    immutable buildGenName = compileBinaries(options);

    //binary backend has no build generator, it _is_ the build
    if(options.backend == Backend.binary) return;

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

    auto binaries = [Binary(buildGenName, compileBuildGenCmd), Binary(dcompileName, dcompileCmd)];
    foreach(bin; binaries) writeln("[Reggae] Compiling metabuild binary ", bin.name);

    import std.parallelism;

    foreach(bin; binaries.parallel) {
        immutable res = execute(bin.cmd);
        enforce(res.status == 0, text("Couldn't execute ", bin.cmd.join(" "), ":\n", res.output,
                                      "\n", "bin.name: ", bin.name, ", bin.cmd: ", bin.cmd.join(" ")));
    }

    return buildGenName;
}

const (string[]) getCompileBuildGenCmd(in Options options) @safe {
    const reggaeSrcs = ("config.d" ~ fileNames).
        filter!(a => a != "dcompile.d").
        map!(a => a.reggaeSrcFileName).array;

    immutable buildBinFlags = options.backend == Backend.binary
        ? ["-O"]
        : [];
    immutable commonBefore = ["dmd",
                              "-I" ~ options.projectPath,
                              "-I" ~ buildPath(hiddenDir, "src"),
                              "-g", "-debug",
                              "-of" ~ getBuildGenName(options)];
    const commonAfter = buildBinFlags ~
        options.reggaeFilePath ~ reggaeSrcs;
    version(minimal) return commonBefore ~ "-version=minimal" ~ commonAfter;
    else return commonBefore ~ commonAfter;
}

string getBuildGenName(in Options options) @safe pure nothrow {
    return options.backend == Backend.binary ? "build" : buildPath(hiddenDir, "buildgen");
}

immutable reggaeSrcDirName = buildPath(hiddenDir, "src", "reggae");

private string filesTupleString() @safe pure nothrow {
    return "TypeTuple!(" ~ fileNames.map!(a => `"` ~ a ~ `"`).join(",") ~ ")";
}

template FileNames() {
    mixin("alias FileNames = " ~ filesTupleString ~ ";");
}


private void writeSrcFiles(in Options options) {
    writeln("[Reggae] Writing reggae source files");

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
        import reggae.types;
        import reggae.options;
    });

    file.writeln("immutable options = ", options, ";");

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
