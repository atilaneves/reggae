module reggae.dub.interop.exec;

import reggae.from;

@safe:


package string callDub(T)(
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


package string[] dubEnvArgs() {
    import std.process: environment;
    import std.string: split;
    return environment.get("REGGAE_DUB_ARGS", "").split(" ");
}


package void dubFetch(T)(auto ref T output,
                         in from!"reggae.options".Options options)
    @trusted
{
    import reggae.io: log;
    import reggae.dub.interop.exec: callDub, dubEnvArgs;
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
private bool needDubFetch(in string dubPackage, in string version_) {
    import reggae.path: dubPackagesDir;
    import std.path: buildPath;
    import std.file: exists;

    return !buildPath(dubPackagesDir,
                      dubPackage ~ "-" ~ version_, dubPackage ~ ".lock")
        .exists;
}


package from!"reggae.dub.info".DubInfo getDubInfo(T)(auto ref T output,
                                                     in from!"reggae.options".Options options)
{
    import reggae.dub.interop: gDubInfos;
    import reggae.dub.interop.configurations: getConfigs;
    import reggae.dub.interop.exec: callDub, configToDubInfo;
    import reggae.io: log;
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

        const configs = getConfigs(output, options);

        bool oneConfigOk;
        Exception dubInfoFailure;

        if(configs.configurations.empty) {
            gDubInfos["default"] = configToDubInfo(output, options, "");
            oneConfigOk = true;
        } else {
            foreach(config; configs.configurations) {
                try {
                    gDubInfos[config] = configToDubInfo(output, options, config);

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
                    output.log("ERROR: Could not get info for configuration ", config, ": ", ex.msg);
                    if(dubInfoFailure is null) dubInfoFailure = ex;
                }
            }

            if(configs.default_ !in gDubInfos)
                throw new Exception("Non-existent config info for " ~ configs.default_);

            gDubInfos["default"] = gDubInfos[configs.default_];
       }

        if(!oneConfigOk) {
            assert(dubInfoFailure !is null,
                   "Internal error: no configurations worked and no exception to throw");
            throw dubInfoFailure;
        }
    }

    return gDubInfos["default"];
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


from!"reggae.dub.info".DubInfo configToDubInfo
    (O)
    (auto ref O output, in from!"reggae.options".Options options, in string config)
{

    import reggae.dub.json: jsonStringToDubInfo;
    import std.typecons: Yes;

    auto cmd = ["dub", "describe"];
    if(config != "") cmd ~= ["-c", config];
    const descOutput = callDub(output, options, cmd, Yes.maybeNoDeps);

    return jsonStringToDubInfo(descOutput);
}
