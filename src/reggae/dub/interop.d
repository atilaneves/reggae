/**
   A module for providing interop between reggae and dub
*/

module reggae.dub.interop;

import reggae.options;
import reggae.dub.info;
import reggae.dub.json;
import std.stdio;
import std.exception;
import std.conv;
import std.process;


DubInfo[string] gDubInfos;


@safe:

struct DubConfigurations {
    string[] configurations;
    string default_;
}


DubConfigurations getConfigurations(in string output) pure {

    import std.algorithm: splitter, find, canFind, until, map;
    import std.string: stripLeft;
    import std.array: array, replace, front, empty;

    auto lines = output.splitter("\n");
    auto fromConfigs = lines.find("Available configurations:").
        until!(a => a == "").
        map!(a => a.stripLeft).
        array[1..$];
    if(fromConfigs.empty) return DubConfigurations();

    immutable defMarker = " [default]";
    auto default_ = fromConfigs.find!(a => a.canFind(defMarker)).front.replace(defMarker, "");
    auto configs = fromConfigs.map!(a => a.replace(defMarker, "")).array;

    return DubConfigurations(configs, default_);
}


void maybeCreateReggaefile(T)(auto ref T output, in Options options) {
    import std.file: exists;

    if(options.isDubProject && !options.reggaeFilePath.exists) {
        createReggaefile(output, options);
    }
}

// default build for a dub project when there is no reggaefile
void createReggaefile(T)(auto ref T output, in Options options) {
    import std.stdio: File;
    import std.path: buildPath;
    import std.regex: regex, replaceFirst;

    output.writeln("[Reggae] Creating reggaefile.d from dub information");
    auto file = File(buildPath(options.workingDir, "reggaefile.d"), "w");
    output.writeln("name: ", buildPath(options.workingDir, "reggaefile.d"));

    file.writeln(q{
        import reggae;
        enum commonFlags = "-w -g -debug";
        mixin build!(dubDefaultTarget!(CompilerFlags(commonFlags)),
                        dubTestTarget!(CompilerFlags(commonFlags)));
    }.replaceFirst(regex(`^        `), ""));

    if(!options.noFetch) dubFetch(output, options);
}


private DubInfo _getDubInfo(T)(auto ref T output, in Options options) {
    import std.array;
    import std.file: exists;
    import std.path: buildPath;
    import std.stdio: writeln;

    version(unittest)
        gDubInfos = null;

    if("default" !in gDubInfos) {

        if(!buildPath(options.projectPath, "dub.selections.json").exists) {
            output.writeln("[Reggae] Calling dub upgrade to create dub.selections.json");
            callDub(options, ["dub", "upgrade"]);
        }

        DubConfigurations getConfigsImpl() {
            immutable dubBuildArgs = ["dub", "--annotate", "build", "--compiler=" ~ options.dCompiler,
                                      "--print-configs", "--build=docs"];
            immutable dubBuildOutput = callDub(options, dubBuildArgs);
            return getConfigurations(dubBuildOutput);
        }

        DubConfigurations getConfigs() {
            try {
                return getConfigsImpl;
            } catch(Exception _) {
                output.writeln("[Reggae] Calling 'dub fetch' since getting the configuration failed");
                dubFetch(output, options);
                return getConfigsImpl;
            }
        }

        const configs = getConfigs();

        bool oneConfigOk;
        Exception dubDescribeFailure;

        if(configs.configurations.empty) {
            const descOutput = callDub(options, ["dub", "describe"]);
            oneConfigOk = true;
            gDubInfos["default"] = getDubInfo(descOutput);
        } else {
            foreach(config; configs.configurations) {
                try {
                    const descOutput = callDub(options, ["dub", "describe", "-c", config]);
                    gDubInfos[config] = getDubInfo(descOutput);

                    // dub adds certain flags to certain configurations automatically but these flags
                    // don't know up in the output to `dub describe`. Special case them here.

                    // unittest should only apply to the main package, hence [0]
                    // this doesn't show up in `dub describe`, it's secret info that dub knows
                    // so we have to add it manually here
                    if(config == "unittest") gDubInfos[config].packages[0].dflags ~= " -unittest";

                    callPreBuildCommands(options, gDubInfos[config]);

                    oneConfigOk = true;

                } catch(Exception ex) {
                    if(dubDescribeFailure !is null) dubDescribeFailure = ex;
                }
            }

            if(configs.default_ !in gDubInfos)
                throw new Exception("Non-existent config info for " ~ configs.default_);

            gDubInfos["default"] = gDubInfos[configs.default_];
       }

        if(!oneConfigOk) throw dubDescribeFailure;
    }

    return gDubInfos["default"];
}

private string callDub(in Options options, in string[] args) {
    import std.process;
    import std.exception: enforce;
    import std.conv: text;
    import std.string;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    immutable workDir = options.projectPath;

    immutable ret = execute(args, env, config, maxOutput, workDir);
    enforce(ret.status == 0, text("Error calling '", args.join(" "), "' (", ret.status, ")", ":\n",
                                  ret.output));
    return ret.output;
}

private void callPreBuildCommands(in Options options, in DubInfo dubInfo) {
    import std.process;
    import std.string: replace;

    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    immutable workDir = options.projectPath;

    foreach(c; dubInfo.packages[0].preBuildCommands) {
        auto cmd = c.replace("$project", options.projectPath);
        immutable ret = executeShell(cmd, env, config, maxOutput, workDir);
        enforce(ret.status == 0, text("Error calling ", cmd, ":\n", ret.output));
    }
}

private void dubFetch(T)(auto ref T output, in Options options) @trusted {
    import std.array: join, replace;
    import std.stdio: writeln;
    import std.path: buildPath;
    import std.json: parseJSON, JSON_TYPE;
    import std.file: readText;

    const fileName = buildPath(options.projectPath, "dub.selections.json");
    auto json = parseJSON(readText(fileName));

    auto versions = json["versions"];

    foreach(dubPackage, versionJson; versions.object) {

        // skip the ones with a defined path
        if(versionJson.type != JSON_TYPE.STRING) continue;

        // versions are usually `==1.2.3`, so strip the sign
        const version_ = versionJson.str.replace("==", "");

        if(!needDubFetch(dubPackage, version_)) continue;

        const cmd = ["dub", "fetch", dubPackage, "--version=" ~ version_];

        output.writeln("[Reggae] Fetching package with command '", cmd.join(" "), "'");
        try
            callDub(options, cmd);
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
    import std.path: buildPath;
    import std.process: environment;
    import std.file: exists;

    const path = buildPath(environment["HOME"], ".dub", "packages", dubPackage ~ "-" ~ version_);
    return !path.exists;
}


void writeDubConfig(T)(auto ref T output, in Options options, File file) {
    import reggae.dub.info: TargetType;
    import std.stdio: writeln;

    output.writeln("[Reggae] Writing dub configuration");

    file.writeln("import reggae.dub.info;");

    if(options.isDubProject) {

        file.writeln("enum isDubProject = true;");
        auto dubInfo = _getDubInfo(output, options);
        const targetType = dubInfo.packages[0].targetType;

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
