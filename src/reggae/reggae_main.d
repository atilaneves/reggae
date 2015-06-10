import std.stdio;
import std.process: execute;
import std.array: array, join, empty;
import std.path: absolutePath, buildPath, relativePath;
import std.typetuple;
import std.file: exists;
import std.conv: text;
import std.exception: enforce;
import std.conv: to;
import reggae.options;
import reggae.ctaa;

version(minimal) {
    enum allFeatures = false;
} else {
    enum allFeatures = true;
}

static if(allFeatures) {
    import reggae.dub.interop;
}

int main(string[] args) {
    try {
        const options = getOptions(args);
        if(options.help) return 0;
        enforce(options.projectPath != "", "A project path must be specified");

        static if(allFeatures) {
        if(options.isDubProject && !projectBuildFile(options).exists) {
            createReggaefile(options);
        }
        }

        createBuild(options);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


string[] getReggaeSrcs(fileNames...)(in Options options) @safe pure nothrow {
    string[] srcs = [reggaeSrcFileName("config.d")];
    foreach(fileName; fileNames) {
        static if(fileName != "dcompile.d") srcs ~= reggaeSrcFileName(fileName);
    }
    return srcs;
}

string[] getCompileCommand(fileNames...)(in Options options) @safe nothrow {
    return ["dmd", "-I" ~ options.projectPath,
            "-of" ~ getBinName(options)] ~
        getReggaeSrcs!(fileNames)(options) ~ getReggaefilePath(options);
}

immutable hiddenDir = ".reggae";

private void createBuild(in Options options) {

    immutable reggaefilePath = getReggaefilePath(options);
    enforce(reggaefilePath.exists, text("Could not find ", reggaefilePath));

    static if(allFeatures) {
        alias fileNames = TypeTuple!("buildgen_main.d",
                                     "build.d",
                                     "backend/make.d", "backend/ninja.d", "backend/binary.d",
                                     "package.d", "range.d", "reflect.d",
                                     "dependencies.d", "types.d", "dcompile.d",
                                     "dub/info.d", "ctaa.d", "sorting.d",
                                     "rules/package.d",
                                     "rules/dub.d", "rules/defaults.d", "rules/common.d",
                                     "rules/d.d", "rules/cpp.d", "rules/c.d",
                                     "core/package.d", "core/rules/package.d",
            );
    } else {
        alias fileNames = TypeTuple!("buildgen_main.d",
                                     "build.d",
                                     "backend/binary.d",
                                     "package.d", "range.d", "reflect.d",
                                     "dependencies.d", "types.d", "dcompile.d",
                                     "ctaa.d", "sorting.d",
                                     "rules/package.d",
                                     "rules/defaults.d", "rules/common.d",
                                     "rules/d.d",
                                     "core/package.d", "core/rules/package.d",
            );
    }
    writeSrcFiles!(fileNames)(options);

    const reggaeSrcs = getReggaeSrcs!(fileNames)(options);
    immutable buildGenName = compileBinaries(options, reggaeSrcs);

    writeln("[Reggae] Running the created binary to generate the build");
    immutable retRunBuildgen = execute([buildPath(".", buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));

    writeln(retRunBuildgen.output);
}

private auto compileBinaries(in Options options, in string[] reggaeSrcs) {
    immutable buildGenName = getBuildBinName(options);
    version(minimal) {
        const compileBuildGenCmd = ["dmd",
                                    "-I" ~ options.projectPath,
                                    "-of" ~ buildGenName,
                                    "-version=minimal"] ~
            getBuildBinFlags(options) ~ reggaeSrcs ~ getReggaefilePath(options);

    } else {
    const compileBuildGenCmd = ["dmd",
                                "-I" ~ options.projectPath,
                                "-of" ~ buildGenName] ~
        getBuildBinFlags(options) ~ reggaeSrcs ~ getReggaefilePath(options);
    }

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

private string getBuildBinName(in Options options) @safe pure nothrow {
    return options.backend == Backend.binary ? "build" : buildPath(hiddenDir, "buildgen");
}

private string[] getBuildBinFlags(in Options options) @safe pure nothrow {
    return options.backend == Backend.binary ? ["-O", "-release", "-inline"] : [];
}


immutable reggaeSrcDirName = buildPath(".reggae", "src", "reggae");


private void writeSrcFiles(fileNames...)(in Options options) {
    import std.file: mkdirRecurse;
    if(!reggaeSrcDirName.exists) {
        mkdirRecurse(reggaeSrcDirName);
        mkdirRecurse(buildPath(reggaeSrcDirName, "dub"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "rules"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "backend"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "core", "rules"));
    }

    foreach(fileName; fileNames) {
        auto file = File(reggaeSrcFileName(fileName), "w");
        file.write(import(fileName));
    }

    writeConfig(options);
}


private void writeConfig(in Options options) {
    auto file = File(reggaeSrcFileName("config.d"), "w");
    file.writeln("module reggae.config;");
    file.writeln("import reggae.ctaa;");
    file.writeln("import reggae.types: Backend;");
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

    static if(allFeatures) {
        writeDubConfig(options, file);
    }
}



private string reggaeSrcFileName(in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName, fileName);
}

private string projectBuildFile(in Options options) @safe pure nothrow {
    return buildPath(options.projectPath, "reggaefile.d");
}

private string getReggaefilePath(in Options options) @safe nothrow {
    immutable regular = projectBuildFile(options);
    if(regular.exists) return regular;
    immutable path = options.isDubProject ? "" : options.projectPath;
    return buildPath(path, "reggaefile.d");
}
