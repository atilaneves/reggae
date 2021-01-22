/**
   A module for providing interop between reggae and dub
*/
module reggae.dub.interop;


import reggae.from;
public import reggae.dub.interop.reggaefile;


from!"reggae.dub.info".DubInfo[string] gDubInfos;


void writeDubConfig(T)(auto ref T output,
                       in from!"reggae.options".Options options,
                       from!"std.stdio".File file) {
    import reggae.io: log;
    import reggae.dub.info: TargetType;
    import reggae.dub.interop.fetch: dubFetch;
    import reggae.dub.interop.dublib: Dub;

    output.log("Writing dub configuration");
    scope(exit) output.log("Finished writing dub configuration");

    if(!options.isDubProject) {
        file.writeln("enum isDubProject = false;");
        return;
    }

    // must check for dub.selections.json before creating dub instance
    const dubSelectionsJson = ensureDubSelectionsJson(output, options);

    auto dub = Dub(options);

    dubFetch(output, dub, options, dubSelectionsJson);

    file.writeln("import reggae.dub.info;");
    file.writeln("enum isDubProject = true;");

    output.log("    Getting dub build information");
    auto dubInfo = getDubInfo(output, dub, options);
    output.log("    Got     dub build information");

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
}


private string ensureDubSelectionsJson
    (O)
    (ref O output, in from!"reggae.options".Options options)
    @safe
{
    import reggae.dub.interop.exec: callDub, dubEnvArgs;
    import reggae.io: log;
    import reggae.path: buildPath;
    import std.file: exists;
    import std.exception: enforce;

    const path = buildPath(options.projectPath, "dub.selections.json");

    if(!path.exists) {
        output.log("Creating dub.selections.json");
        const cmd = ["dub", "upgrade"] ~ dubEnvArgs;
        callDub(output, options, cmd);
    }

    enforce(path.exists, "Could not create dub.selections.json");

    return path;
}



private from!"reggae.dub.info".DubInfo getDubInfo
    (T)
    (auto ref T output,
     ref from!"reggae.dub.interop.dublib".Dub dub,
     in from!"reggae.options".Options options)
{
    import reggae.dub.interop: gDubInfos;
    import reggae.io: log;
    import reggae.path: buildPath;
    import std.array: empty;
    import std.file: exists;
    import std.conv: text;
    import std.exception: enforce;

    version(unittest) gDubInfos = null;

    if("default" !in gDubInfos) {

        enforce(buildPath(options.projectPath, "dub.selections.json").exists,
                "Cannot find dub.selections.json");

        auto settings = dub.getGeneratorSettings(options);

        const configs = dub.getConfigs(settings.platform);

        bool oneConfigOk;
        Exception dubInfoFailure;

        if(configs.configurations.empty) {
            gDubInfos["default"] = dub.configToDubInfo(settings, "");
            oneConfigOk = true;
        } else {
            foreach(config; configs.configurations) {
                try {
                    gDubInfos[config] = dub.configToDubInfo(settings, config);

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
                        gDubInfos[config].packages[0].dflags ~= "-unittest";
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
                                     in from!"reggae.dub.info".DubInfo dubInfo)
    @safe
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
