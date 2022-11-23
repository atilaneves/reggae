/**
   A module for providing interop between reggae and dub
*/
module reggae.dub.interop;


import reggae.from;
public import reggae.dub.interop.reggaefile;


from!"reggae.dub.info".DubInfo[string] gDubInfos;


void writeDubConfig(O)(ref O output,
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
    (O)
    (ref O output,
     ref from!"reggae.dub.interop.dublib".Dub dub,
     in from!"reggae.options".Options options)
{
    import reggae.dub.interop: gDubInfos;
    import reggae.io: log;
    import reggae.path: buildPath;
    import std.file: exists;
    import std.exception: enforce;

    version(unittest) gDubInfos = null;

    if("default" !in gDubInfos) {

        enforce(buildPath(options.projectPath, "dub.selections.json").exists,
                "Cannot find dub.selections.json");

        auto settings = dub.getGeneratorSettings(options);
        const configs = dubConfigurations(output, dub, options, settings);
        const haveTestConfig = configs.test != "";
        bool atLeastOneConfigOk;
        Exception dubInfoFailure;

        foreach(config; configs.configurations) {
            const isTestConfig = haveTestConfig && config == configs.test;
            try {
                gDubInfos[config] = handleDubConfig(output, dub, options, settings, config, isTestConfig);
                atLeastOneConfigOk = true;
            } catch(Exception ex) {
                output.log("ERROR: Could not get info for configuration ", config, ": ", ex.msg);
                if(dubInfoFailure is null) dubInfoFailure = ex;
            }
        }

        if(!atLeastOneConfigOk) {
            assert(dubInfoFailure !is null,
                   "Internal error: no configurations worked and no exception to throw");
            throw dubInfoFailure;
        }

        gDubInfos["default"] = gDubInfos[configs.default_];

        // (additionally) expose the special `dub test` config as `unittest` config in the DSL (`configToDubInfo`)
        // (for `dubTestTarget!()`, `dubConfigurationTarget!(Configuration("unittest"))` etc.)
        if(haveTestConfig && configs.test != "unittest" && configs.test in gDubInfos)
            gDubInfos["unittest"] = gDubInfos[configs.test];
    }

    return gDubInfos["default"];
}

private from!"reggae.dub.interop.configurations".DubConfigurations
dubConfigurations
    (O)
    (ref O output,
     ref from!"reggae.dub.interop.dublib".Dub dub,
     in from!"reggae.options".Options options,
     in from!"dub.generators.generator".GeneratorSettings settings)
{
    import reggae.dub.interop.configurations: DubConfigurations;
    import reggae.io: log;

    const allConfigs = options.dubConfig == "";

    if(allConfigs) output.log("Getting dub configurations");
    auto ret = dub.getConfigs(settings, options.dubConfig);
    if(allConfigs) output.log("Number of dub configurations: ", ret.configurations.length);

    // error out if the test config is explicitly requested but not available
    if(options.dubConfig == "unittest" && ret.test == "") {
        output.log("ERROR: No dub test configuration available (target type 'none'?)");
        throw new Exception("No dub test configuration");
    }

    // this happens e.g. the targetType is "none"
    if(ret.configurations.length == 0)
        return DubConfigurations([""], "", null);

    return ret;
}

private from!"reggae.dub.info".DubInfo handleDubConfig
    (O)
    (ref O output,
     ref from!"reggae.dub.interop.dublib".Dub dub,
     in from!"reggae.options".Options options,
     from!"dub.generators.generator".GeneratorSettings settings,
     in string config,
     in bool isTestConfig)
{
    import reggae.io: log;
    import std.conv: text;

    output.log("Querying dub configuration '", config, "'");

    auto dubInfo = dub.configToDubInfo(settings, config);

    /**
     For the `dub test` config, add `-unittest` (only for the main package, hence [0]).
     [Similarly, `dub test` implies `--build=unittest`, with the unittest build type
     being the debug one + `-unittest`.]

     This enables (assuming no custom reggaefile.d):
     * `reggae && ninja default ut`
       => default `debug` build type for default config, extra `-unittest` for test config
     * `reggae --dub-config=unittest && ninja`
       => no need for extra `--dub-build-type=unittest`
     */
    if(isTestConfig) {
        if(dubInfo.packages.length == 0)
            throw new Exception(
                text("No main package in `", config, "` configuration"));
        dubInfo.packages[0].dflags ~= "-unittest";
    }

    try
        callPreBuildCommands(output, options, dubInfo);
    catch(Exception e) {
        output.log("Error calling prebuild commands: ", e.msg);
        throw e;
    }

    return dubInfo;
}


private void callPreBuildCommands(O)(ref O output,
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
