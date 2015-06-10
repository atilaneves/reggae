/**
 A module for providing interop between reggae and dub
 */

module reggae.dub.interop;

import reggae.options;
import reggae.dub_info;
import reggae.dub_call;
import reggae.dub_json;
import std.stdio;
import std.exception;
import std.conv;
import std.process;

DubInfo[string] gDubInfos;


@safe:

version(minimal) {
    enum allFeatures = false;
} else {
    enum allFeatures = true;
}

void createReggaefile(in Options options) {
    writeln("[Reggae] Creating reggaefile.d from dub information");
    auto file = File("reggaefile.d", "w");
    file.writeln("import reggae;");
    file.writeln("mixin build!dubDefaultTarget;");

    static if(allFeatures) {
        if(!options.noFetch) dubFetch(_getDubInfo(options));
    }
}


static if(allFeatures) {
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

static if(allFeatures) {
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
}

void writeDubConfig(in Options options, File file) {
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
