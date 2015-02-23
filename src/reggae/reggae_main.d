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


immutable reggaeSrcDirName = buildPath(".reggae", "src", "reggae");


int main(string[] args) {
    try {
        immutable options = getOptions(args);
        enforce(options.projectPath != "", "A project path must be specified");

        if(isDubProject(options.projectPath)) {
            import std.process;
            const string[string] env = null;
            Config config = Config.none;
            size_t maxOutput = size_t.max;
            immutable workDir = options.projectPath;

            immutable dubArgs = ["dub", "describe"];
            immutable ret = execute(dubArgs, env, config, maxOutput, workDir);
            enforce(ret.status == 0, text("Could not get description from dub with ", dubArgs, ":\n",
                                          ret.output));

            auto dubInfo = dubInfo(ret.output);

            auto file = File(buildPath(options.projectPath, "reggaefile.d"), "w");
            file.writeln("import reggae;");
            file.writeln("Build bld() {");
            file.writeln("  auto info = ", dubInfo, ";");
            file.writeln("  auto objs = info.toTargets;");


            string makeRelative(in string path) @safe pure {
                return buildPath(options.projectPath, path).absolutePath.relativePath(
                    options.projectPath.absolutePath);
            }

            file.writeln("  return Build(dExeRuntime(App(`",
                         dubInfo.packages[0].mainSourceFile, "`, `",
                         dubInfo.packages[0].targetFileName, "`), ",
                         "Flags(`", dubInfo.packages[0].flags.join(" "), "`),",
                         "ImportPaths(", dubInfo.importPaths.map!makeRelative, "), ",
                         "StringImportPaths(", dubInfo.stringImportPaths.map!makeRelative, "), []));");
            file.writeln("}");
        }

        createBuild(options);
    } catch(Exception ex) {
        stderr.writeln(ex.msg);
        return 1;
    }

    return 0;
}


void createBuild(in Options options) {

    immutable buildFileName = buildPath(options.projectPath, "reggaefile.d");
    enforce(buildFileName.exists, text("Could not find ", buildFileName));

    alias fileNames = TypeTuple!("buildgen_main.d",
                                 "build.d",
                                 "makefile.d", "ninja.d", "options.d",
                                 "package.d", "range.d", "reflect.d",
                                 "rules.d", "dependencies.d", "types.d",
                                 "dub.d");
    writeSrcFiles!(fileNames)(options);
    string[] reggaeSrcs = [reggaeSrcFileName("config.d")];
    foreach(fileName; fileNames) {
        reggaeSrcs ~= reggaeSrcFileName(fileName);
    }

    immutable binName = "buildgen";
    const compile = ["dmd", "-g", "-debug","-I" ~ options.projectPath,
                     "-of" ~ binName] ~ reggaeSrcs ~ buildFileName;

    immutable retCompBuildgen = execute(compile);
    enforce(retCompBuildgen.status == 0,
            text("Couldn't execute ", compile.join(" "), ":\n", retCompBuildgen.output));

    immutable retRunBuildgen = execute([buildPath(".",  binName), "-b", options.backend, options.projectPath]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", binName, " binary:\n", retRunBuildgen.output));

    immutable retCompDcompile = execute(["dmd",
                                         reggaeSrcFileName("dcompile.d"),
                                         reggaeSrcFileName("dependencies.d")]);
    enforce(retCompDcompile.status == 0, text("Couldn't compile dcompile.d:\n", retCompDcompile.output));

}

private bool isDubProject(in string projectPath) @safe {
    return buildPath(projectPath, "dub.json").exists ||
        buildPath(projectPath, "package.json").exists;
}


void writeSrcFiles(fileNames...)(in Options options) {
    import std.file: mkdirRecurse;
    if(!reggaeSrcDirName.exists) mkdirRecurse(reggaeSrcDirName);

    foreach(fileName; fileNames) {
        auto file = File(reggaeSrcFileName(fileName), "w");
        file.write(import(fileName));
    }
    {
        auto file = File(reggaeSrcFileName("dcompile.d"), "w");
        file.write(import("dcompile.d"));
    }
    {
        auto file = File(reggaeSrcFileName("config.d"), "w");
        file.writeln("module reggae.config;");
        file.writeln("immutable projectPath = `", options.projectPath, "`;");
    }
}


string reggaeSrcFileName(in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName, fileName);
}
