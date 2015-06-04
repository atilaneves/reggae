import std.stdio;
import std.process: execute;
import std.array: array, join, empty;
import std.path: absolutePath, buildPath, relativePath;
import std.typetuple;
import std.file: exists;
import std.conv: text;
import std.exception: enforce;
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

        if(isDubProject(options.projectPath) && !projectBuildFile(options).exists) {
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
    const dubInfo = _getDubInfo(options);

    auto file = File("reggaefile.d", "w");
    file.writeln("import reggae;");
    file.writeln("Build bld() {");
    file.writeln("    auto info = ", dubInfo, ";");
    file.writeln("    return Build(info.mainTarget);");
    file.writeln("}");

    if(!options.noFetch) dubFetch(dubInfo);
}

private void createBuild(in Options options) {

    immutable buildFileName = getBuildFileName(options);
    enforce(buildFileName.exists, text("Could not find ", buildFileName));

    alias fileNames = TypeTuple!("buildgen_main.d",
                                 "build.d",
                                 "makefile.d", "ninja.d",
                                 "package.d", "range.d", "reflect.d",
                                 "dependencies.d", "types.d",
                                 "dub_info.d", "ctaa.d", "sorting.d",
                                 "rules/package.d",
                                 "rules/dub.d", "rules/defaults.d", "rules/common.d",
                                 "rules/d.d", "rules/cpp.d", "rules/c.d");
    writeSrcFiles!(fileNames)(options);
    string[] reggaeSrcs = [reggaeSrcFileName("config.d")];
    foreach(fileName; fileNames) {
        reggaeSrcs ~= reggaeSrcFileName(fileName);
    }

    immutable reggaeDir = ".reggae";
    immutable binName = buildPath(reggaeDir, "buildgen");
    const compile = ["dmd", "-g", "-debug","-I" ~ options.projectPath,
                     "-of" ~ binName] ~ reggaeSrcs ~ buildFileName;

    immutable retCompBuildgen = execute(compile);
    enforce(retCompBuildgen.status == 0,
            text("Couldn't execute ", compile.join(" "), ":\n", retCompBuildgen.output));

    immutable retRunBuildgen = execute([buildPath(".",  binName), "-b", options.backend, options.projectPath]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", binName, " binary:\n", retRunBuildgen.output));
    writeln(retRunBuildgen.output);

    immutable retCompDcompile = execute(["dmd",
                                         "-O", "-release", "-inline",
                                         "-of" ~ buildPath(reggaeDir, "dcompile"),
                                         reggaeSrcFileName("dcompile.d"),
                                         reggaeSrcFileName("dependencies.d")]);
    enforce(retCompDcompile.status == 0, text("Couldn't compile dcompile.d:\n", retCompDcompile.output));

}

private bool isDubProject(in string projectPath) @safe {
    return buildPath(projectPath, "dub.json").exists ||
        buildPath(projectPath, "package.json").exists;
}


immutable reggaeSrcDirName = buildPath(".reggae", "src", "reggae");
immutable reggaeRulesSrcDirName = buildPath(reggaeSrcDirName, "rules");


private void writeSrcFiles(fileNames...)(in Options options) {
    import std.file: mkdirRecurse;
    if(!reggaeSrcDirName.exists) {
        mkdirRecurse(reggaeSrcDirName);
        mkdirRecurse(reggaeRulesSrcDirName);
    }

    foreach(fileName; fileNames) {
        auto file = File(reggaeSrcFileName(fileName), "w");
        file.write(import(fileName));
    }

    //necessary due to dmd's lack of -MMD option
    auto file = File(reggaeSrcFileName("dcompile.d"), "w");
    file.write(import("dcompile.d"));

    writeConfig(options);
}


private void writeConfig(in Options options) {
    auto file = File(reggaeSrcFileName("config.d"), "w");
    file.writeln("module reggae.config;");
    file.writeln("import reggae.dub_info;");
    file.writeln("import reggae.ctaa;");
    file.writeln("enum projectPath = `", options.projectPath, "`;");
    file.writeln("enum backend = `", options.backend, "`;");
    file.writeln("enum dflags = `", options.dflags, "`;");
    file.writeln("enum reggaePath = `", options.reggaePath, "`;");
    file.writeln("enum buildFilePath = `", options.getBuildFileName.absolutePath, "`;");
    file.writeln("enum cCompiler = `", options.cCompiler, "`;");
    file.writeln("enum cppCompiler = `", options.cppCompiler, "`;");
    file.writeln("enum dCompiler = `", options.dCompiler, "`;");
    file.writeln("enum perModule = ", options.perModule, ";");
    file.writeln("enum userVars = AssocList!(string, string)([");
    foreach(key, value; options.userVars) {
        file.writeln("assocEntry(`", key, "`, `", value, "`), ");
    }
    file.writeln("]);");

    if(isDubProject(options.projectPath)) {
        file.writeln("enum isDubProject = true;");
        auto dubInfo = _getDubInfo(options);
        immutable targetType = dubInfo.packages[0].targetType;
        enforce(targetType == "executable" || targetType == "library",
                text("Unsupported dub targetType '", targetType, "'"));

        file.writeln(`const configToDubInfo = assocList([`);
        foreach(config; gDubInfos.keys) {
            file.writeln(`    assocEntry("`, config, `", `, gDubInfos[config], `),`);
        }
        file.writeln(`]);`);
        file.writeln;
        file.writeln(`auto dubInfo() { return configToDubInfo["default"]; }`);
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

private string getBuildFileName(in Options options) {
    immutable regular = projectBuildFile(options);
    if(regular.exists) return regular;
    immutable path = isDubProject(options.projectPath) ? "" : options.projectPath;
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
