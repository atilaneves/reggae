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

    maybeCreateReggaefile(options);
    createBuild(options);
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
    immutable newer = thisExeNewer;
    writeSrcFiles(options, newer);

    //compile the binaries (the build generator and dcompile)
    immutable buildGenName = compileBinaries(options, newer);

    //binary backend has no build generator, it _is_ the build
    if(options.backend == Backend.binary) return;

    //actually run the build generator
    writeln("[Reggae] Running the created binary to generate the build");
    immutable retRunBuildgen = execute([buildPath(".", buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));

    writeln(retRunBuildgen.output);
}

private bool newerThan(in string a, in string b) nothrow {
    try {
        return a.timeLastModified > b.timeLastModified;
    } catch(Exception) { //file not there, so newer
        return true;
    }
}

private bool thisExeNewer() {
    return thisExePath.newerThan(reggaeLibName);
}

private immutable hiddenDir = ".reggae";
private immutable reggaeLibName = buildPath(hiddenDir, "libreggae.a");


private auto compileBinaries(in Options options, in bool newer) {
    if(newer) {
        const reggaeLibCmd  = getCompileReggaeLibCmd(options);
        writeln("[Reggae] Rebuilding ", reggaeLibName);

        immutable libRes = execute(reggaeLibCmd);
        enforce(libRes.status == 0,
                text("Could not execute ", reggaeLibCmd.join(" "), ":\n", libRes.output));
    }

    immutable buildGenName = getBuildGenName(options);
    const compileBuildGenCmd = getCompileBuildGenCmd(options);

    immutable dcompileName = buildPath(hiddenDir, "dcompile");
    immutable dcompileCmd = ["dmd",
                             "-I.reggae/src",
                             "-of" ~ dcompileName,
                             reggaeSrcFileName("dcompile.d"),
                             reggaeSrcFileName("dependencies.d")];


    static struct Binary { string name; const(string)[] cmd; }

    auto binaries = [Binary(buildGenName, compileBuildGenCmd)];
    if(newer) binaries ~= Binary(dcompileName, dcompileCmd);
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
    immutable buildBinFlags = options.backend == Backend.binary
        ? ["-O"]
        : [];
    immutable commonBefore = ["dmd",
                              "-I" ~ options.projectPath,
                              "-I" ~ buildPath(hiddenDir, "src"),
                              "-g", "-debug",
                              "-of" ~ getBuildGenName(options)];
    const commonAfter = buildBinFlags ~
        options.reggaeFilePath ~ reggaeSrcFileName("config.d") ~
        reggaeLibName;
    version(minimal) return commonBefore ~ "-version=minimal" ~ commonAfter;
    else return commonBefore ~ commonAfter;
}


string[] getCompileReggaeLibCmd(in Options options) @safe {
    const reggaeSrcs = fileNames.
        filter!(a => a != "dcompile.d").
        map!(a => a.reggaeSrcFileName).array;

    immutable commonBefore = ["dmd",
                              "-I" ~ options.projectPath,
                              "-I" ~ buildPath(hiddenDir, "src"),
                              "-g", "-debug",
                              "-of" ~ reggaeLibName,
                              "-lib"];
    const commonAfter = reggaeSrcs;
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


private void writeSrcFiles(in Options options, in bool newer) {
    writeln("[Reggae] Writing reggae source files");

    if(newer) {

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
