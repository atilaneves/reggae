/**
   A module for providing interop between reggae and dub
*/
module reggae.dub.interop;


import reggae.from;


from!"reggae.dub.info".DubInfo[string] gDubInfos;


@safe:

struct DubConfigurations {
    string[] configurations;
    string default_;
}


DubConfigurations getConfigurations(in string rawOutput) pure {

    import std.algorithm: findSkip, filter, map, canFind, startsWith;
    import std.string: splitLines, stripLeft;
    import std.array: array, replace;

    string output = rawOutput;  // findSkip mutates output
    const found = output.findSkip("Available configurations:");
    assert(found, "Could not find configurations in:\n" ~ rawOutput);
    auto configs = output
        .splitLines
        .filter!(a => a.startsWith("  "))
        .map!stripLeft
        .array;

    if(configs.length == 0) return DubConfigurations();

    enum defaultMarker = " [default]";

    string default_;
    foreach(ref config; configs) {
        if(config.canFind(defaultMarker)) {
            assert(default_ is null);
            config = config.replace(defaultMarker, "");
            default_ = config;
            break;
        }
    }

    return DubConfigurations(configs, default_);
}


void maybeCreateReggaefile(T)(auto ref T output,
                              in from!"reggae.options".Options options)
{
    import std.file: exists;

    if(options.isDubProject && !options.reggaeFilePath.exists) {
        createReggaefile(output, options);
    }
}

// default build for a dub project when there is no reggaefile
void createReggaefile(T)(auto ref T output,
                         in from!"reggae.options".Options options)
{
    import reggae.io: log;
    import std.stdio: File;
    import std.path: buildPath;
    import std.regex: regex, replaceFirst;

    output.log("Creating reggaefile.d from dub information");
    auto file = File(buildPath(options.projectPath, "reggaefile.d"), "w");

    file.writeln(q{
        import reggae;
        enum commonFlags = "-w -g -debug";
        mixin build!(dubDefaultTarget!(CompilerFlags(commonFlags)),
                        dubTestTarget!(CompilerFlags(commonFlags)));
    }.replaceFirst(regex(`^        `), ""));

    if(!options.noFetch) dubFetch(output, options);
}


private from!"reggae.dub.info".DubInfo _getDubInfo(T)(auto ref T output,
                                                      in from!"reggae.options".Options options)
{
    import reggae.io: log;
    import reggae.dub.json: jsonStringToDubInfo;
    import std.array;
    import std.file: exists;
    import std.path: buildPath;
    import std.stdio: writeln;
    import std.typecons: Yes;
    import std.conv: text;

    version(unittest) gDubInfos = null;

    if("default" !in gDubInfos) {

        if(!buildPath(options.projectPath, "dub.selections.json").exists) {
            callDub(output, options, ["dub", "upgrade"]);
        }

        DubConfigurations tryGetConfigs() {
            immutable dubBuildArgs = ["dub", "--annotate", "build", "--compiler=" ~ options.dCompiler,
                                      "--print-configs", "--build=docs"];
            immutable dubBuildOutput = callDub(output, options, dubBuildArgs, Yes.maybeNoDeps);
            return getConfigurations(dubBuildOutput);
        }

        DubConfigurations getConfigs() {
            try {
                return tryGetConfigs;
            } catch(Exception _) {
                output.log("Calling `dub fetch` since getting the configuration failed");
                dubFetch(output, options);
                return tryGetConfigs;
            }
        }

        const configs = getConfigs();

        bool oneConfigOk;
        Exception dubDescribeFailure;

        if(configs.configurations.empty) {
            const descOutput = callDub(output, options, ["dub", "describe"], Yes.maybeNoDeps);
            oneConfigOk = true;
            gDubInfos["default"] = jsonStringToDubInfo(descOutput);
        } else {
            foreach(config; configs.configurations) {
                try {
                    const descOutput = callDub(output, options, ["dub", "describe", "-c", config], Yes.maybeNoDeps);
                    gDubInfos[config] = jsonStringToDubInfo(descOutput);

                    // dub adds certain flags to certain configurations automatically but these flags
                    // don't know up in the output to `dub describe`. Special case them here.

                    // unittest should only apply to the main package, hence [0].
                    // This doesn't show up in `dub describe`, it's secret info that dub knows
                    // so we have to add it manually here.
                    if(config == "unittest") {
                        if(config !in gDubInfos)
                            throw new Exception(
                                text("Configuration `", config, "` not found in ",
                                     () @trusted { return gDubInfos.keys; }()));
                        if(gDubInfos[config].packages.length == 0)
                            throw new Exception(
                                text("No main package in `", config, "` configuration"));
                        gDubInfos[config].packages[0].dflags ~= " -unittest";
                    }

                    try
                        callPreBuildCommands(output, options, gDubInfos[config]);
                    catch(Exception e) {
                        output.log("Error calling prebuild commands: ", e.msg);
                        throw e;
                    }

                    oneConfigOk = true;

                } catch(Exception ex) {
                    output.log("ERROR: exception in calling dub describe: ", ex.msg);
                    if(dubDescribeFailure is null) dubDescribeFailure = ex;
                }
            }

            if(configs.default_ !in gDubInfos)
                throw new Exception("Non-existent config info for " ~ configs.default_);

            gDubInfos["default"] = gDubInfos[configs.default_];
       }

        if(!oneConfigOk) {
            assert(dubDescribeFailure !is null,
                   "Internal error: no configurations worked and no exception to throw");
            throw dubDescribeFailure;
        }
    }

    return gDubInfos["default"];
}

private string callDub(T)(
    auto ref T output,
    in from!"reggae.options".Options options,
    in string[] rawArgs,
    from!"std.typecons".Flag!"maybeNoDeps" maybeNoDeps = from!"std.typecons".No.maybeNoDeps)
{
    import reggae.io: log;
    import std.process: execute, Config;
    import std.exception: enforce;
    import std.conv: text;
    import std.string: join, split;
    import std.path: buildPath;
    import std.file: exists;

    const hasSelections = buildPath(options.projectPath, "dub.selections.json").exists;
    string[] emptyArgs;
    const noDepsArgs = hasSelections && maybeNoDeps ? ["--nodeps", "--skip-registry=all"] : emptyArgs;
    const archArg = rawArgs[1] == "fetch" || rawArgs[1] == "upgrade"
        ? emptyArgs
        : ["--arch=" ~ options.dubArch.text];
    const args = rawArgs ~ noDepsArgs ~ dubEnvArgs ~ archArg;
    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    const workDir = options.projectPath;

    output.log("Calling `", args.join(" "), "`");
    const ret = execute(args, env, config, maxOutput, workDir);
    enforce(ret.status == 0,
            text("Error calling `", args.join(" "), "` (", ret.status, ")", ":\n",
                 ret.output));

    return ret.output;
}

private string[] dubEnvArgs() {
    import std.process: environment;
    import std.string: split;
    return environment.get("REGGAE_DUB_ARGS", "").split(" ");
}

private void callPreBuildCommands(T)(auto ref T output,
                                     in from!"reggae.options".Options options,
                                     in from!"reggae.dub.json".DubInfo dubInfo)
{
    import reggae.io: log;
    import std.process: executeShell, Config;
    import std.string: replace;
    import std.exception: enforce;
    import std.conv: text;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    immutable workDir = options.projectPath;

    if(dubInfo.packages.length == 0) return;

    foreach(const package_; dubInfo.packages) {
        foreach(const dubCommandString; package_.preBuildCommands) {
            auto cmd = dubCommandString.replace("$project", options.projectPath);
            output.log("Executing pre-build command `", cmd, "`");
            const ret = executeShell(cmd, env, config, maxOutput, workDir);
            enforce(ret.status == 0, text("Error calling ", cmd, ":\n", ret.output));
        }
    }
}

private void dubFetch(T)(auto ref T output,
                         in from!"reggae.options".Options options)
    @trusted
{
    import reggae.io: log;
    import std.array: join, replace;
    import std.stdio: writeln;
    import std.path: buildPath;
    import std.json: parseJSON, JSONType;
    import std.file: readText;

    const fileName = buildPath(options.projectPath, "dub.selections.json");
    auto json = parseJSON(readText(fileName));

    auto versions = json["versions"];

    foreach(dubPackage, versionJson; versions.object) {

        // skip the ones with a defined path
        if(versionJson.type != JSONType.string) continue;

        // versions are usually `==1.2.3`, so strip the sign
        const version_ = versionJson.str.replace("==", "");

        if(!needDubFetch(dubPackage, version_)) continue;


        const cmd = ["dub", "fetch", dubPackage, "--version=" ~ version_] ~ dubEnvArgs;

        try
            callDub(output, options, cmd);
        catch(Exception ex) {
            // local packages can't be fetched, so it's normal to get an error
            if(!options.dubLocalPackages)
                throw ex;
        }
    }
}

// dub fetch can sometimes take >10s (!) despite the package already being
// on disk
bool needDubFetch(in string dubPackage, in string version_) {
    import reggae.path: dubPackagesDir;
    import std.path: buildPath;
    import std.file: exists;

    return !buildPath(dubPackagesDir,
                      dubPackage ~ "-" ~ version_, dubPackage ~ ".lock")
        .exists;
}


void writeDubConfig(T)(auto ref T output,
                       in from!"reggae.options".Options options,
                       from!"std.stdio".File file) {
    import reggae.io: log;
    import reggae.dub.info: TargetType;

    output.log("Writing dub configuration");

    file.writeln("import reggae.dub.info;");

    if(options.isDubProject) {

        file.writeln("enum isDubProject = true;");
        auto dubInfo = _getDubInfo(output, options);
        const targetType = dubInfo.packages.length
            ? dubInfo.packages[0].targetType
            : TargetType.sourceLibrary;

        file.writeln(`const configToDubInfo = assocList([`);

        const keys = () @trusted { return gDubInfos.keys; }();
        foreach(config; keys) {
            file.writeln(`    assocEntry("`, config, `", `, gDubInfos[config], `),`);
        }
        file.writeln(`]);`);
        file.writeln;
    } else {
        file.writeln("enum isDubProject = false;");
    }
}
