/**
   A module for providing interop between reggae and dub
*/

module reggae.dub.interop;

import reggae.options;
import reggae.dub.info;
import reggae.dub.call;
import reggae.dub.json;
import std.stdio;
import std.exception;
import std.conv;
import std.process;

DubInfo[string] gDubInfos;


@safe:

void maybeCreateReggaefile(in Options options) {
    if(options.isDubProject && !options.projectBuildFile.exists) {
        createReggaefile(options);
    }
}

void createReggaefile(in Options options) {
    writeln("[Reggae] Creating reggaefile.d from dub information");
    auto file = File("reggaefile.d", "w");
    file.writeln(q{import reggae;});
    file.writeln(q{mixin build!(dubDefaultTarget!(),
                                dubTestTarget!());});

    if(!options.noFetch) dubFetch(_getDubInfo(options));
}


private DubInfo _getDubInfo(in Options options) {

    if("default" !in gDubInfos) {
        immutable dubBuildArgs = ["dub", "--annotate", "build", "--compiler=dmd", "--print-configs"];
        immutable dubBuildOutput = callDub(options, dubBuildArgs);
        immutable configs = getConfigurations(dubBuildOutput);

        if(configs.configurations.empty) {
            immutable descArgs = ["dub", "describe"];
            immutable descOutput = callDub(options, descArgs);
            gDubInfos["default"] = getDubInfo(descOutput);
        } else {
            foreach(config; configs.configurations) {
                immutable descArgs = ["dub", "describe", "-c", config];
                immutable descOutput = callDub(options, descArgs);
                gDubInfos[config] = getDubInfo(descOutput);

                //dub adds certain flags to certain configurations automatically but these flags
                //don't know up in the output to `dub describe`. Special case them here.

                //unittest should only apply to the main package, hence [0]
                if(config == "unittest") gDubInfos[config].packages[0].flags ~= " -unittest";

                callPreBuildCommands(options, gDubInfos[config]);

            }
            gDubInfos["default"] = gDubInfos[configs.default_];
        }
    }

    return gDubInfos["default"];
}


private string callDub(in Options options, in string[] args) {
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

private void callPreBuildCommands(in Options options, in DubInfo dubInfo) {
    import std.process;
    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    immutable workDir = options.projectPath;

    foreach(cmd; dubInfo.packages[0].preBuildCommands) {
        writeln("Calling dub prebuildCommand '", cmd, "'");
        immutable ret = executeShell(cmd, env, config, maxOutput, workDir);
        enforce(ret.status == 0, text("Error calling ", cmd, ":\n", ret.output));
    }
}

private void dubFetch(in DubInfo dubInfo) {
    foreach(cmd; dubInfo.fetchCommands) {
        immutable cmdStr = "'" ~ cmd.join(" ") ~ "'";
        writeln("Fetching package with cmd ", cmdStr);
        immutable ret = execute(cmd);
        if(ret.status) {
            () @trusted {
                stderr.writeln("Could not execute dub fetch with:\n", cmd.join(" "), "\n",
                               ret.output);
            }();
        }
    }
}


void writeDubConfig(in Options options, File file) {
    file.writeln("import reggae.dub.info;");
    if(options.isDubProject) {
        file.writeln("enum isDubProject = true;");
        auto dubInfo = _getDubInfo(options);
        immutable targetType = dubInfo.packages[0].targetType;
        enforce(targetType == "executable" || targetType == "library" || targetType == "staticLibrary",
                text("Unsupported dub targetType '", targetType, "'"));

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
