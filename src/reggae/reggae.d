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
import std.process: execute, environment;
import std.array: array, join, empty, split;
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
import reggae.file;


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

    if(options.reggaeFileLanguage != BuildLanguage.D) {
        immutable haveToReturn = jsonBuild(options, options.reggaeFileLanguage);
        if(haveToReturn) return;
    }

    maybeCreateReggaefile(options);
    createBuild(options);
}

//get JSON description of the build from a scripting language
//return true if no D files are present
bool jsonBuild(in Options options, in BuildLanguage language) {
    enforce(options.backend != Backend.binary, "Binary backend not supported via JSON");

    immutable jsonOutput = getJsonOutput(options, language);

    import reggae.json_build;
    import reggae.buildgen;
    import reggae.rules.common: Language;

    const build = jsonToBuild(options.projectPath, jsonOutput);
    generateBuild(build, options);

    //true -> exit early
    return !build.targets.canFind!(a => a.getLanguage == Language.D);
}

private string getJsonOutput(in Options options, in BuildLanguage language) @safe {
    const args = getJsonOutputArgs(options, language);
    const nodePaths = environment.get("NODE_PATH", "").split(":");
    const luaPaths = environment.get("LUA_PATH", "").split(";");
    auto env = ["NODE_PATH": (nodePaths ~ options.projectPath).join(":"),
                "LUA_PATH": (luaPaths ~ buildPath(options.projectPath, "?.lua")).join(";")];
    immutable res = execute(args, env);
    enforce(res.status == 0, text("Could not execute ", args.join(" "), ":\n", res.output));
    return res.output;
}

private string[] getJsonOutputArgs(in Options options, in BuildLanguage language) @safe pure nothrow {
    final switch(language) {

    case BuildLanguage.D:
        assert(0, "Cannot obtain JSON build for builds written in D");

    case BuildLanguage.Python:
        return ["python", "-m", "reggae.json_build", options.projectPath];

    case BuildLanguage.Ruby:
        return ["ruby", "-S", "-I" ~ options.projectPath, "reggae_json_build.rb"];

    case BuildLanguage.Lua:
        return ["reggae_json_build.lua"];

    case BuildLanguage.JavaScript:
        return ["reggae_json_build.js"];
    }
}

enum coreFiles = [
    "options.d",
    "buildgen_main.d", "buildgen.d",
    "build.d",
    "backend/package.d", "backend/binary.d",
    "package.d", "range.d", "reflect.d",
    "dependencies.d", "types.d", "dcompile.d",
    "ctaa.d", "sorting.d", "file.d",
    "rules/package.d",
    "rules/common.d",
    "rules/d.d",
    "rules/c_and_cpp.d",
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

    enforce(options.reggaeFilePath.exists, text("Could not find ", options.reggaeFilePath));

    //write out the library source files to be compiled with the user's
    //build description
    writeSrcFiles(options);

    //compile the binaries (the build generator and dcompile)
    immutable buildGenName = compileBinaries(options);

    //binary backend has no build generator, it _is_ the build
    if(options.backend == Backend.binary) return;

    //only got here to build .dcompile
    if(options.isScriptBuild) return;

    //actually run the build generator
    writeln("[Reggae] Running the created binary to generate the build");
    immutable retRunBuildgen = execute([buildPath(".", buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));

    writeln(retRunBuildgen.output);
}


struct Binary {
    string name;
    const(string)[] cmd;
}

private void buildBinary(in Binary bin) {
    writeln("[Reggae] Compiling metabuild binary ", bin.name);
    immutable res = execute(bin.cmd);
    enforce(res.status == 0, text("Couldn't execute ", bin.cmd.join(" "), ":\n", res.output,
                                  "\n", "bin.name: ", bin.name, ", bin.cmd: ", bin.cmd.join(" ")));

}

private auto buildDCompile(in Options options) {
    immutable name = buildPath(hiddenDir, "dcompile");

    if(!thisExePath.newerThan(name)) return;

    immutable cmd = ["dmd",
                     "-I.reggae/src",
                     "-of" ~ name,
                     reggaeSrcFileName("dcompile.d"),
                     reggaeSrcFileName("dependencies.d")];

    buildBinary(Binary(name, cmd));
}

private string compileBinaries(in Options options) {
    buildDCompile(options);

    immutable buildGenName = getBuildGenName(options);
    const buildGenCmd = getCompileBuildGenCmd(options);

    buildBinary(Binary(buildGenName ~ ".o", buildGenCmd));

    const reggaeFileDeps = getReggaeFileDependencies;
    auto objFiles = [buildGenName ~ ".o"];
    if(!reggaeFileDeps.empty) {
        immutable rest = buildPath(hiddenDir, "rest.o");
        buildBinary(Binary(rest,
                           ["dmd",
                            "-of" ~ buildPath(hiddenDir, "rest.o"),
                            "-I" ~ options.projectPath,
                            "-I" ~ buildPath(hiddenDir, "src"),
                            "-c"] ~
                           reggaeFileDeps));
        objFiles ~= rest;
    }
    buildBinary(Binary(buildGenName, ["dmd", "-of" ~ buildGenName] ~ objFiles));


    return buildGenName;
}


private string[] getCompileBuildGenCmd(in Options options) @safe {
    import reggae.rules.common: objExt;

    const reggaeSrcs = ("config.d" ~ fileNames).
        filter!(a => a != "dcompile.d").
        map!(a => a.reggaeSrcFileName).array;

    immutable buildBinFlags = options.backend == Backend.binary
        ? ["-O"]
        : [];
    immutable commonBefore = [buildPath(hiddenDir, "dcompile"),
                              "--objFile=" ~ getBuildGenName(options) ~ objExt,
                              "--depFile=" ~ buildPath(hiddenDir, "reggaefile.dep"),
                              "dmd",
                              "-I" ~ options.projectPath,
                              "-I" ~ buildPath(hiddenDir, "src"),
                              "-g",
                              "-debug"];
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
