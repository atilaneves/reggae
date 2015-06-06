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
import reggae.dub_json;
import reggae.dub_info;
import reggae.ctaa;
import reggae.dub_call;


int main(string[] args) {
    try {
        const options = getOptions(args);
        if(options.help) return 0;
        enforce(options.projectPath != "", "A project path must be specified");

        if(options.isDubProject && !projectBuildFile(options).exists) {
            createReggaefile(options);
        }

        createBuild(options);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}

DubInfo[string] gDubInfos;

private void createReggaefile(in Options options) {
    auto file = File("reggaefile.d", "w");
    file.writeln("import reggae;");
    file.writeln("mixin build!dubDefaultTarget;");

    if(!options.noFetch) dubFetch(_getDubInfo(options));
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

    alias fileNames = TypeTuple!("buildgen_main.d",
                                 "build.d",
                                 "backend/make.d", "backend/ninja.d", "backend/binary.d",
                                 "package.d", "range.d", "reflect.d",
                                 "dependencies.d", "types.d", "dcompile.d",
                                 "dub_info.d", "ctaa.d", "sorting.d",
                                 "rules/package.d",
                                 "rules/dub.d", "rules/defaults.d", "rules/common.d",
                                 "rules/d.d", "rules/cpp.d", "rules/c.d");
    writeSrcFiles!(fileNames)(options);

    const reggaeSrcs = getReggaeSrcs!(fileNames)(options);
    immutable buildGenName = compileBinaries(options, reggaeSrcs);

    immutable retRunBuildgen = execute([buildPath(".", buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));

    writeln(retRunBuildgen.output);
}

private auto compileBinaries(in Options options, in string[] reggaeSrcs) {
    immutable buildGenName = getBuildBinName(options);
    const compileBuildGenCmd = ["dmd",
                                "-I" ~ options.projectPath,
                                "-of" ~ buildGenName] ~
        getBuildBinFlags(options) ~ reggaeSrcs ~ getReggaefilePath(options);

    immutable dcompileCmd = ["dmd",
                             "-I.reggae/src",
                             "-of" ~ buildPath(hiddenDir, "dcompile"),
                             reggaeSrcFileName("dcompile.d"),
                             reggaeSrcFileName("dependencies.d")];


    import std.parallelism;
    foreach(cmd; [compileBuildGenCmd, dcompileCmd].parallel) {
        immutable res = execute(cmd);
        enforce(res.status == 0, text("Couldn't execute ", cmd.join(" "), ":\n"), res.output);
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

        immutable reggaeRulesSrcDirName = buildPath(reggaeSrcDirName, "rules");
        mkdirRecurse(reggaeRulesSrcDirName);

        immutable reggaeBackendSrcDirName = buildPath(reggaeSrcDirName, "backend");
        mkdirRecurse(reggaeBackendSrcDirName);
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
    file.writeln("import reggae.dub_info;");
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

    if(options.isDubProject) {
        file.writeln("enum isDubProject = true;");
        auto dubInfo = _getDubInfo(options);
        immutable targetType = dubInfo.packages[0].targetType;
        enforce(targetType == "executable" || targetType == "library" || targetType == "staticLibrary",
                text("Unsupported dub targetType '", targetType, "'"));

        file.writeln(`const configToDubInfo = assocList([`);
        foreach(config; gDubInfos.keys) {
            file.writeln(`    assocEntry("`, config, `", `, gDubInfos[config], `),`);
        }
        file.writeln(`]);`);
        file.writeln;
    } else {
        file.writeln("enum isDubProject = false;");
    }
}

private DubInfo _getDubInfo(in Options options) {

    if("default" !in gDubInfos) {
        immutable dubBuildArgs = ["dub", "--annotate", "build", "--compiler=dmd", "--print-configs"];
        immutable dubBuildOutput = _callDub(options, dubBuildArgs);
        immutable configs = getConfigurations(dubBuildOutput);

        if(configs.configurations.empty) {
            immutable descArgs = ["dub", "describe"];
            immutable descOutput = _callDub(options, descArgs);
            gDubInfos["default"] = getDubInfo(descOutput);
        } else {
            foreach(config; configs.configurations) {
                immutable descArgs = ["dub", "describe", "-c", config];
                immutable descOutput = _callDub(options, descArgs);
                gDubInfos[config] = getDubInfo(descOutput);
            }
            gDubInfos["default"] = gDubInfos[configs.default_];
        }
    }

    return gDubInfos["default"];
}

private string _callDub(in Options options, in string[] args) {
    import std.process;
    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    immutable workDir = options.projectPath;

    immutable ret = execute(args, env, config, maxOutput, workDir);
    enforce(ret.status == 0, text("Error calling ", args.join(" "), ":\n",
                                  ret.output));
    return ret.output;
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

//@trusted because of writeln
private void dubFetch(in DubInfo dubInfo) @trusted {
    foreach(cmd; dubInfo.fetchCommands) {
        immutable cmdStr = "'" ~ cmd.join(" ") ~ "'";
        writeln("Fetching package with cmd ", cmdStr);
        immutable ret = execute(cmd);
        if(ret.status) {
            stderr.writeln("Could not execute dub fetch with:\n", cmd.join(" "), "\n",
                ret.output);
        }
    }
}
