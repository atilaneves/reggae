/**
   A module for providing interop between reggae and dub
*/
module reggae.dub.interop;
version(Have_dub):

string dubConfigSource(O)(ref O output, in imported!"reggae.options".Options options) {
    import reggae.dub.info: TargetType;

    string ret;

    void append(A...)(auto ref A args) {
        import std.conv: text;
        ret ~= text(args, "\n");
    }

    if(!options.isDubProject) {
        append("enum isDubProject = false;");
        return ret;
    }

    auto dubInfos = dubInfos(output, options);

    const targetType = dubInfos["default"].packages.length
        ? dubInfos["default"].packages[0].targetType
        : TargetType.sourceLibrary;

    append("import reggae.dub.info;");
    append("enum isDubProject = true;");
    append(`const configToDubInfo = assocList([`);

    foreach(k, v; dubInfos) {
        append(`    assocEntry("`, k, `", `, v, `),`);
    }
    append(`]);`);

    append;

    return ret;
}


/**
   Returns an associative array of string -> DubInfo, where the string
   is the name of a dub configuration.
 */
imported!"reggae.dub.info".DubInfo[string] dubInfos(O)
    (ref O output,
     in imported!"reggae.options".Options options)
{
    import reggae.io: log;
    import reggae.dub.interop.dublib: Dub, fetchDubDeps;
    import std.file: readText;

    output.log("Fetching dub dependencies");
    fetchDubDeps(options.projectPath);
    output.log("Dub dependencies fetched");

    output.log("Creating dub instance");
    auto dub = Dub(options);
    output.log("Getting dub information");
    auto ret = getDubInfos(output, dub);
    output.log("Got dub build information");

    return ret;
}

private imported!"reggae.dub.info".DubInfo[string] getDubInfos
    (O)
    (ref O output,
     ref imported!"reggae.dub.interop.dublib".Dub dub)
{
    import reggae.io: log;
    import reggae.path: buildPath;
    import reggae.dub.info: DubInfo;
    import std.file: exists;
    import std.exception: enforce;

    DubInfo[string] ret;

    enforce(buildPath(dub.options.projectPath, "dub.selections.json").exists,
            "Cannot find dub.selections.json");

    const configs = dubConfigurations(output, dub);
    const haveTestConfig = configs.test != "";
    bool atLeastOneConfigOk;
    Exception dubInfoFailure;

    foreach(config; configs.configurations) {
        const isTestConfig = haveTestConfig && config == configs.test;
        try {
            ret[config] = configToDubInfo(output, dub, config, isTestConfig);
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

    ret["default"] = ret[configs.default_];

    // (additionally) expose the special `dub test` config as
    // `unittest` config in the DSL (`configToDubInfo`) (for
    // `dubTest!()`, `dubBuild!(Configuration("unittest"))` etc.)
    if(haveTestConfig && configs.test != "unittest" && configs.test in ret)
        ret["unittest"] = ret[configs.test];

    return ret;
}


private imported!"reggae.dub.interop.configurations".DubConfigurations
dubConfigurations
    (O)
    (ref O output,
     ref imported!"reggae.dub.interop.dublib".Dub dub)
{
    import reggae.dub.interop.configurations: DubConfigurations;
    import reggae.io: log;

    output.log("Getting dub configurations");
    auto ret = dub.getConfigs;
    output.log("Number of dub configurations: ", ret.configurations.length);

    // this happens e.g. the targetType is "none"
    if(ret.configurations.length == 0)
        return DubConfigurations([""], "", null);

    return ret;
}

private imported!"reggae.dub.info".DubInfo configToDubInfo
    (O)
    (ref O output,
     ref imported!"reggae.dub.interop.dublib".Dub dub,
     in string config,
     in bool isTestConfig)
{
    import reggae.io: log;
    import std.conv: text;

    output.log("Querying dub configuration '", config, "'");

    auto dubInfo = dub.configToDubInfo(config);

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
        callPreBuildCommands(output, dub.options.projectPath, dubInfo);
    catch(Exception e) {
        output.log("Error calling prebuild commands: ", e.msg);
        throw e;
    }

    return dubInfo;
}


private void callPreBuildCommands(O)(ref O output,
                                     in string workDir,
                                     in imported!"reggae.dub.info".DubInfo dubInfo)
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

    if(dubInfo.packages.length == 0) return;

    foreach(const package_; dubInfo.packages) {
        foreach(const dubCommandString; package_.preBuildCommands) {
            auto cmd = dubCommandString.replace("$project", workDir);
            output.log("Executing pre-build command `", cmd, "`");
            const ret = executeShell(cmd, env, config, maxOutput, workDir);
            enforce(ret.status == 0, text("Error calling ", cmd, ":\n", ret.output));
        }
    }
}
