/**
 The main entry point for the reggae tool. Its tasks are:
 $(UL
   $(LI Verify that a $(D reggafile.d) exists in the selected directory)
   $(LI Generate a $(D reggaefile.d) for dub projects)
   $(LI Write out the reggae library files and $(D config.d))
   $(LI Compile the build description with the reggae library files to produce $(D buildgen))
   $(LI Call the produced $(D buildgen) binary)
 )
 */

module reggae.reggae;

import std.stdio;
import std.process: execute, environment;
import std.array: array, join, empty, split;
import std.typetuple;
import std.file;
import std.conv: text;
import std.exception: enforce;
import std.conv: to;
import std.algorithm;

import reggae.options;
import reggae.ctaa;
import reggae.types;
import reggae.file;
import reggae.path: buildPath;


version(minimal) {
    //empty stubs for minimal version of reggae
    void writeDubConfig(T...)(T) {}
} else {
    import reggae.dub.interop: writeDubConfig;
}

mixin template reggaeGen(targets...) {
    mixin buildImpl!targets;
    mixin ReggaeMain;
}

mixin template ReggaeMain() {
    import reggae.options: getOptions;
    import std.stdio: stdout, stderr;

    int main(string[] args) {
        try {
            run(stdout, args);
        } catch(Exception ex) {
            stderr.writeln(ex.msg);
            return 1;
        }

        return 0;
    }
}

void run(T)(auto ref T output, string[] args) {
    auto options = getOptions(args);
    run(output, options);
}

void run(T)(auto ref T output, Options options) {

    if(options.earlyExit) return;

    enforce(options.projectPath != "", "A project path must be specified");

    // if there's no custom reggaefile, execute and exit early
    if(dubBuild(options)) return;

    // write out the library source files to be compiled/interpreted
    // with the user's build description
    writeSrcFiles(output, options);

    if(options.isJsonBuild) {
        immutable haveToReturn = jsonBuild(options);
        if(haveToReturn) return;
    }

    createBuild(output, options);
}

//get JSON description of the build from a scripting language
//and transform it into a build description
//return true if no D files are present
private bool jsonBuild(Options options) {
    import reggae.json_build;

    immutable jsonOutput = getJsonOutput(options);
    auto build = jsonToBuild(options, options.projectPath, jsonOutput);

    return runtimeBuild(jsonToOptions(options, jsonOutput), build);
}

// Call dub, get the build description, and generate the build now
private bool dubBuild(in Options options) {
    import reggae.dub.interop.default_build: defaultDubBuild;
    import std.file: exists;

    if(options.reggaeFilePath.exists)
        return false;

    auto build = defaultDubBuild(options);
    return runtimeBuild(options, build);
}

private bool runtimeBuild(in Options options, imported!"reggae.build".Build build) {
    version(minimal)
        assert(0, "Runtime builds not supported in minimal version");
    else {
        import reggae.buildgen: doBuild;

        if(build == build.init) return false;

        // The binary backend requires `args` to not be empty because
        // the first entry must be the binary name. We also don't want
        // to rerun ourselves from here.
        auto args = ["build", "--norerun"];
        doBuild(build, options, args);
    }

    return true;
}

private string getJsonOutput(in Options options) @safe {
    const args = getJsonOutputArgs(options);
    const path = environment.get("PATH", "").split(":");
    const pythonPaths = environment.get("PYTHONPATH", "").split(":");
    const nodePaths = environment.get("NODE_PATH", "").split(":");
    const luaPaths = environment.get("LUA_PATH", "").split(";");
    const srcDir = buildPath(hiddenDirAbsPath(options), "src");
    const binDir = buildPath(srcDir, "reggae");
    auto env = ["PATH": (path ~ binDir).join(":"),
                "PYTHONPATH": (pythonPaths ~ srcDir).join(":"),
                "NODE_PATH": (nodePaths ~ options.projectPath ~ binDir).join(":"),
                "LUA_PATH": (luaPaths ~ buildPath(options.projectPath, "?.lua") ~ buildPath(binDir, "?.lua")).join(";")];
    immutable res = execute(args, env);
    enforce(res.status == 0, text("Could not execute ", args.join(" "), ":\n", res.output));
    return res.output;
}

private string[] getJsonOutputArgs(in Options options) @safe {

    import std.process: environment;
    import std.json: parseJSON;

    final switch(options.reggaeFileLanguage) {

    case BuildLanguage.D:
        assert(0, "Cannot obtain JSON build for builds written in D");

    case BuildLanguage.Python:

        auto optionsString = () @trusted {
            import std.json;
            import std.traits;
            auto jsonVal = parseJSON(`{}`);
            foreach(member; __traits(allMembers, typeof(options))) {
                static if(is(typeof(mixin(`options.` ~ member)) == const(Backend)) ||
                          is(typeof(mixin(`options.` ~ member)) == const(string)) ||
                          is(typeof(mixin(`options.` ~ member)) == const(bool)) ||
                          is(typeof(mixin(`options.` ~ member)) == const(string[string])) ||
                          is(typeof(mixin(`options.` ~ member)) == const(string[])))
                    jsonVal.object[member] = mixin(`options.` ~ member);
            }
            return jsonVal.toString;
        }();

        const haveReggaePython = "REGGAE_PYTHON" in environment;
        auto pythonParts = haveReggaePython
            ? [environment["REGGAE_PYTHON"]]
            : ["/usr/bin/env", "python"];
        return pythonParts ~ ["-B", "-m", "reggae.reggae_json_build",
                "--options", optionsString,
                options.projectPath];

    case BuildLanguage.Ruby:
        return ["ruby", "-S",
                "-I" ~ options.projectPath,
                "-I" ~ buildPath(hiddenDirAbsPath(options), "src/reggae"),
                "reggae_json_build.rb"];

    case BuildLanguage.Lua:
        return ["lua", buildPath(hiddenDirAbsPath(options), "src/reggae/reggae_json_build.lua")];

    case BuildLanguage.JavaScript:
        return ["node", buildPath(hiddenDirAbsPath(options), "src/reggae/reggae_json_build.js")];
    }
}

private enum coreFiles = [
    "options.d",
    "buildgen_main.d", "buildgen.d",
    "build.d",
    "backend/package.d", "backend/binary.d",
    "package.d", "range.d",
    "dependencies.d", "types.d",
    "ctaa.d", "sorting.d", "file.d",
    "rules/package.d",
    "rules/common.d",
    "rules/d.d",
    "rules/c_and_cpp.d",
    "core/package.d", "core/rules/package.d",
    ];
private enum otherFiles = [
    "backend/ninja.d", "backend/make.d", "backend/tup.d",
    "dub/interop/configurations.d",
    "dub/interop/dublib.d",
    "dub/interop/exec.d",
    "dub/interop/fetch.d",
    "dub/interop/package.d",
    "dub/interop/default_build.d",
    "dub/info.d", "rules/dub.d",
    "path.d",
    "io.d",
    ];

version(minimal) {
    private enum string[] foreignFiles = [];
} else {
    private enum foreignFiles = [
        "__init__.py", "build.py", "reflect.py", "rules.py", "reggae_json_build.py",
        "reggae.rb", "reggae_json_build.rb",
        "reggae-js.js", "reggae_json_build.js",
        "JSON.lua", "reggae.lua", "reggae_json_build.lua",
        ];
}

//all files that need to be written out and compiled
private string[] fileNames() @safe pure nothrow {
    version(minimal)
        return coreFiles;
    else
        return coreFiles ~ otherFiles;
}


private void createBuild(T)(auto ref T output, in Options options) {

    import reggae.io: log;

    enforce(options.reggaeFilePath.exists, text("Could not find ", options.reggaeFilePath));

    // no need to build the description if interpreting it
    if(options.isScriptBuild) return;

    //compile the the build generator
    immutable buildGenName = compileBuildGenerator(output, options);

    //binary backend has no build generator, it _is_ the build
    if(options.backend == Backend.binary) return;


    //actually run the build generator
    output.log("Running the created binary to generate the build");
    immutable retRunBuildgen = execute([buildPath(hiddenDirAbsPath(options), buildGenName)]);
    enforce(retRunBuildgen.status == 0,
            text("Couldn't execute the produced ", buildGenName, " binary:\n", retRunBuildgen.output));
    output.log("Build generated");

    if(retRunBuildgen.output.length) output.log(retRunBuildgen.output);
}


struct Binary {
    string name;
    const(string)[] cmd;
}


private enum dubSdl =
`
    name "buildgen"
    targetType "executable"
    sourceFiles %s // user files (reggaefile.d + dependencies)
    importPaths %s // to pick up potential reggaefile.d dependencies
    dependency "dub" version="*" // version fixed by dub.selections.json
`;
private string compileBuildGenerator(T)(auto ref T output, in Options options) {

    import reggae.rules.common: exeExt, objExt;
    import std.format: format;
    import std.file: write;
    import std.path: buildPath;
    import std.algorithm: map, joiner, any, canFind;
    import std.range: chain, only;
    import std.string: replace;
    import std.array: array;

    immutable buildGenName = getBuildGenName(options) ~ exeExt;
    if(options.isScriptBuild) return buildGenName;

    enum dubRules = [ "dubPackage", "dubDependency" ];
    const needsDubAtRuntime = dubRules.any!(a => options.reggaeFilePath.readText.canFind(a));

    // `options.getReggaeFileDependenciesDlang` depends on
    // `options.reggaeFileDepFile` existing, which means we need to
    // compile the reggaefile separately to get those dependencies
    // *then* add any extra files to the dummy dub.sdl.
    const dubVersions = needsDubAtRuntime ? ["Have_dub", "DubUseCurl"] : [];
    const versionFlag = options.isLdc ? "-d-version" : "-version";
    const dubVersionFlags = dubVersions.map!(a => versionFlag ~ "=" ~ a).array;
    auto reggaefileObj = Binary(
        "reggaefile" ~ objExt,
        [
            options.dCompiler,
            options.reggaeFilePath, "-o-", "-makedeps=" ~ options.reggaeFileDepFile,
         ]
        ~ dubVersionFlags ~ importPaths(options) ~ dubImportFlags(options),
    );
    buildBinary(output, options, reggaefileObj);

    // quote and separate with spaces for .sdl
    static stringsToSdlList(R)(R strings) {
        return strings
            .map!(s => s.replace(`\`, `/`))
            .map!(s => `"` ~ s ~ `"`)
            .joiner(" ");
    }

    auto userFiles = chain(
        options.reggaeFilePath.only,
        options.getReggaeFileDependenciesDlang
    );
    auto userSourceFilesForDubSdl = stringsToSdlList(userFiles);
    // [2..$] gets rid of `-I`
    auto importPathsForDubSdl = stringsToSdlList(importPaths(options).map!(i => i[2..$]));

    write(
        buildPath(hiddenDirAbsPath(options), "dub.sdl"),
        dubSdl.format(
            userSourceFilesForDubSdl,
            importPathsForDubSdl,
        ),
    );
    write(
        buildPath(hiddenDirAbsPath(options), "dub.selections.json"),
        import("dub.selections.json")
    );

    auto binary = () {
        import std.algorithm;
        import std.file: readText;

        // FIXME - use --compiler
        // The reason it doesn't work now is due to a test using
        // a custom compiler
        if(needsDubAtRuntime)
            return Binary(
                buildGenName,
                ["dub", "build"], // since we now depend on dub at buildgen runtime
                );

        return Binary(
            buildGenName,
            ["dmd", "-of" ~ getBuildGenName(options), "-i", options.reggaeFilePath] ~ importPaths(options)
            ~ buildPath(hiddenDirAbsPath(options), "src", "reggae", "buildgen_main.d"),
            );
    }();

    buildBinary(output, options, binary);

    return buildGenName;
}

private string[] dubImportFlags(in imported!"reggae.options".Options options) {
    import std.json: parseJSON;
    import dub.dub: Dub, FetchOptions;
    import dub.dependency: Version;
    import std.file: exists;
    import std.path: buildPath;
    import reggae.path: dubPackagesDir;

    const dubSelectionsJson = import("dub.selections.json");
    const dubVersion = dubSelectionsJson
        .parseJSON
        ["versions"]
        ["dub"]
        .str;
    auto dubObj = new Dub(options.projectPath);
    dubObj.fetch("dub", Version(dubVersion), dubObj.defaultPlacementLocation, FetchOptions.none);
    const dubSourcePath = buildPath(dubPackagesDir, "dub", dubVersion, "dub", "source");
    assert(dubSourcePath.exists, "dub fetch failed: no path '" ~ dubSourcePath ~ "'");
    return ["-I" ~ dubSourcePath];
}

private void buildBinary(T)(auto ref T output, in Options options, in Binary bin) {
    import reggae.io: log;
    import std.process;

    string[string] env;
    auto config = Config.none;
    auto maxOutput = size_t.max;
    auto workDir = hiddenDirAbsPath(options);
    const extraInfo = options.verbose
        ? " with " ~  bin.cmd.join(" ")
        : "";
    output.log("Compiling metabuild binary ", bin.name, extraInfo);
    // std.process.execute has a bug where using workDir and a relative path
    // don't work (https://issues.dlang.org/show_bug.cgi?id=15915)
    // so executeShell is used instead
    immutable res = executeShell(bin.cmd.join(" "), env, config, maxOutput, workDir);
    enforce(
        res.status == 0,
        text("Couldn't execute ", bin.cmd.join(" "), "\nin ", workDir,
             ":\n", res.output,
             "\n", "bin.name: ", bin.name, ", bin.cmd: ", bin.cmd.join(" ")));

}

private string[] importPaths(in Options options) @safe nothrow {
    import std.file: exists;
    import std.algorithm: map;
    import std.array: array;
    import std.range: chain, only;
    import std.path: buildPath;

    auto imports = chain(only(buildPath(hiddenDirAbsPath(options), "src")), options.reggaefileImportPaths)
        .map!(p => "-I" ~ p)
        .array;
    auto projPathImport = "-I" ~ options.projectPath;
    // if compiling phobos, the includes for the reggaefile.d compilation
    // will pick up the new phobos if we include the src path
    return "std".exists ? imports : projPathImport ~ imports;
}

private string getBuildGenName(in Options options) @safe pure nothrow {
    return options.backend == Backend.binary ? buildPath("../build") : "buildgen";
}

private void writeSrcFiles(T)(auto ref T output, in Options options) {
    import reggae.io: log;

    output.log("Writing reggae source files");

    import std.file: mkdirRecurse;
    immutable reggaeSrcDirName = reggaeSrcDirName(options);
    if(!reggaeSrcDirName.exists) {
        mkdirRecurse(reggaeSrcDirName);
        mkdirRecurse(buildPath(reggaeSrcDirName, "dub/interop"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "rules"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "backend"));
        mkdirRecurse(buildPath(reggaeSrcDirName, "core/rules"));
    }

    //this foreach has to happen at compile time due
    //to the string import below.
    foreach(fileName; aliasSeqOf!(fileNames ~ foreignFiles)) {
        auto file = File(reggaeSrcFileName(options, fileName), "w");
        file.write(import(fileName));
    }

    writeConfig(output, options);
}

private string reggaeSrcDirName(in Options options) @safe pure nothrow {
    import std.path: buildPath;
    static immutable reggaeSrcRelDirName = buildPath("src/reggae");
    return buildPath(hiddenDirAbsPath(options), reggaeSrcRelDirName);
}

private void writeConfig(T)(auto ref T output, in Options options) {

    import reggae.io: log;

    output.log("Writing reggae configuration");

    auto file = File(reggaeSrcFileName(options, "config.d"), "w");

    file.writeln(q{
module reggae.config;
import reggae.ctaa;
import reggae.types;
import reggae.options;
    });

    version(minimal) file.writeln("enum isDubProject = false;");
    file.writeln("immutable options = ", options, ";");

    file.writeln("enum userVars = AssocList!(string, string)([");
    foreach(key, value; options.userVars) {
        file.writeln("assocEntry(`", key, "`, `", value, "`), ");
    }
    file.writeln("]);");

    try {
        writeDubConfig(output, options, file);
    } catch(Exception ex) {
        stderr.writeln("Could not write dub configuration: ", ex.msg);
        throw ex;
    }
}


private string reggaeSrcFileName(in Options options, in string fileName) @safe pure nothrow {
    return buildPath(reggaeSrcDirName(options), fileName);
}

private string hiddenDirAbsPath(in Options options) @safe pure nothrow {
    import std.path: buildPath;
    return buildPath(options.workingDir, hiddenDir);
}
