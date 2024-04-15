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

    // Write out the config.d file
    writeConfig(output, options);

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
    const srcDir = reggaeSrcDirName(options);
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
                "-I" ~ reggaePkgDirName(options),
                "reggae_json_build.rb"];

    case BuildLanguage.Lua:
        return ["lua", reggaeSrcFileName(options, "reggae_json_build.lua")];

    case BuildLanguage.JavaScript:
        return ["node", reggaeSrcFileName(options, "reggae_json_build.js")];
    }
}

private void createBuild(T)(auto ref T output, in Options options) {

    import reggae.io: log;
    import std.process: spawnProcess, wait;
    import std.path: baseName;

    enforce(options.reggaeFilePath.exists, text("Could not find ", options.reggaeFilePath));

    // no need to build the description if interpreting it
    if(options.isScriptBuild) return;

    //compile the the build generator
    immutable buildGenName = compileBuildGenerator(output, options);

    //binary backend has no build generator, it _is_ the build
    if(options.backend == Backend.binary) return;

    //actually run the build generator
    output.log("Running the created binary to generate the build");
    immutable buildgenStatus = spawnProcess([buildGenName]).wait();
    enforce(buildgenStatus == 0,
            text("Executing the produced ", buildGenName.baseName, " binary failed"));
    output.log("Build generated");
}


struct Binary {
    string name;
    const(string)[] cmd;
}


private string compileBuildGenerator(T)(auto ref T output, in Options options) {

    import std.algorithm: any, canFind;
    import std.typecons: Yes, No;

    immutable buildGenName = getBuildGenName(options);
    if(options.isScriptBuild) return buildGenName;

    // Only depend on dub if needed to. Right now there's only two rules that require
    // the dependency.
    enum dubRules = [ "dubPackage", "dubDependant" ];
    const reggaefileNeedsDubDep = dubRules.any!(a => options.reggaeFilePath.readText.canFind(a));
    const needsDub = reggaefileNeedsDubDep ? Yes.needDub : No.needDub;

    if(options.buildReggaefileWithDub) {
        const binary = buildReggaefileDub(output, options, needsDub);
        buildBinary(output, options, binary);
        return buildGenName;
    }

    return buildReggaefileWithReggae(options, needsDub);
}

private enum reggaeFileDubSdl =
`
name "buildgen"
targetType "executable"
 // user files (reggaefile.d, buildgen_main.d, dependencies imported by the reggaefile)
sourceFiles %s
 // to pick up potential reggaefile.d dependencies
importPaths %s
dependency "reggae" path="packages/reggae"
`;

private enum libReggaeRecipeNoDub =
`
name "reggae"
targetType "staticLibrary"
`;

private enum libReggaeRecipeDub = libReggaeRecipeNoDub ~
`
dependency "dub" version="*" // version fixed by dub.selections.json
subConfiguration "dub" "library"
`;

private enum reggaeFileDubSelectionsJson =
`
{
        "fileVersion": 1,
        "versions": {
                "dub": %s,
                "reggae": {"path":"packages/reggae"}
        }
}
`;


// dub support is needed at runtime, build and link with dub-as-a-library
private Binary buildReggaefileDub(O)(
    auto ref O output,
    in Options options,
    imported!"std.typecons".Flag!"needDub" needDub,
    )
{
    import std.format: format;
    import std.path: buildPath;
    import std.algorithm: map, joiner;
    import std.range: chain, only;
    import std.array: replace, join;

     // calculates .dep so getReggaeFileDependenciesDlang works below
    calculateReggaeFileDeps(output, options);

    // quote and separate with spaces for .sdl
    static stringsToSdlList(R)(R strings) {
        return strings
            .map!(s => s.replace(`\`, `/`))
            .map!(s => `"` ~ s ~ `"`)
            .joiner(" ");
    }

    auto userFiles = chain(
        buildGenMainSrcPath(options).only,
        options.reggaeFilePath.only,
        options.getReggaeFileDependenciesDlang // must be called after .dep file created
    );
    auto userSourceFilesForDubSdl = stringsToSdlList(userFiles);
    // [2..$] gets rid of `-I`
    auto importPathsForDubSdl = stringsToSdlList(importPaths(options).map!(i => i[2..$]));

    // write these first so that trying to get import paths for dub
    // and its transitive dependencies works in `dubImportPaths`
    // below.
    const dubRecipeDir = hiddenDirAbsPath(options);
    const dubRecipePath = buildPath(dubRecipeDir, "dub.sdl");

    const linesIfBinary = [
        `targetPath ".."`,
        `targetName "build"`,
    ];
    const extraLines = options.backend == Backend.binary
        ? linesIfBinary
        : [];

    writeIfDiffers(
        output,
        dubRecipePath,
        reggaeFileDubSdl.format(
            userSourceFilesForDubSdl,
            importPathsForDubSdl,
        ) ~ extraLines.join("\n"),
    );

    writeIfDiffers(
        output,
        buildPath(dubRecipeDir, "dub.selections.json"),
        reggaeFileDubSelectionsJson.format(selectionsPkgVersion!"dub"),
    );

    const reggaeRecipePath = buildPath(reggaeSrcDirName(options), "..", "dub.sdl");
    const libReggaeRecipe = needDub ? libReggaeRecipeDub : libReggaeRecipeNoDub;
    writeIfDiffers(
        output,
        reggaeRecipePath,
        libReggaeRecipe,
    );

    // FIXME - use --compiler
    // The reason it doesn't work now is due to a test using
    // a custom compiler
    return Binary(
        getBuildGenName(options),
        ["dub", "build"], // since we now depend on dub at buildgen runtime
    );
}

// create a .dep file with the dependencies of the reggaefile so we
// can compile them
private void calculateReggaeFileDeps(O)(auto ref O output, in Options options) {
    import reggae.io: log;
    import reggae.build: Target, Command;

    // `options.getReggaeFileDependenciesDlang` depends on
    // `options.reggaeFileDepFile` existing, which means we need to
    // compile the reggaefile separately to get those dependencies
    // *then* add any extra files to the dummy dub.sdl.
    // *Must* be done before attempting
    // options.getReggaeFileDependenciesDlang.
    auto target = Target(
        options.reggaeFileDepFile,
        Command(
            (in string[] inputs, in string[] outputs) {
                auto reggaefileObj = Binary(
                    options.reggaeFileDepFile, // the name doesn't really matter
                    [
                        options.dCompiler,
                        options.reggaeFilePath, "-o-", "-makedeps=" ~ options.reggaeFileDepFile,
                        ]
                    ~ importPaths(options),
                );

                output.log("Calculating reggaefile dependencies");
                buildBinary(output, options, reggaefileObj);
            }
        ),
        options.reggaeFilePath,
    );

    buildTarget(options, target); // run the command
}

// build a target using reggae as a build system
private void buildTarget(in Options options, imported!"reggae.build".Target target) {
    import reggae.types: Backend;
    import reggae.build: Build;

    auto newOptions = options.dup;
    newOptions.backend = Backend.binary;
    runtimeBuild(newOptions, Build(target));
}

private void writeIfDiffers(O)(auto ref O output, in string path, in string contents) @safe {
    import reggae.io: log;
    import std.file: exists, readText, write, mkdirRecurse;
    import std.path: dirName;

    if(!path.exists || !strEqModNewLine(path.readText, contents)) {
        output.log("Writing ", path);
        if(!path.dirName.exists)
            mkdirRecurse(path.dirName);
        write(path, contents);
    }
}


// the dub/unit-threaded version we depend on
private imported!"std.json".JSONValue selectionsPkgVersion(string pkg)() @safe pure {
    import std.json: parseJSON;

    // enforce CTFE, checking the JSON at compile-time
    enum selection = import("dub.selections.json")
        .parseJSON
        ["versions"]
        [pkg];

    return selection;
}


// builds the reggaefile custom dub project using reggae itself.
// I put a build system in the build system so it can build system while it build systems.
// Currently slower than using dub because of multiple thread scheduling but also because
// building per package is causing linker errors.
private string buildReggaefileWithReggae(
    in imported!"reggae.options".Options options,
    imported!"std.typecons".Flag!"needDub" needDub,)
{
    import reggae.rules.dub: dubPackage, DubPath;
    import reggae.build: Build;
    import std.typecons: Yes;

    // HACK: needs refactoring, calling this just to create the phony dub package
    // for the reggaefile build
    import std.stdio: stdout;
    buildReggaefileDub(stdout, options, Yes.needDub);

    const dubRecipeDir = hiddenDirAbsPath(options);

    // FIXME - use correct D compiler.
    // The reason it doesn't work now is due to a test using
    // a custom compiler
    // It's not clear that the reggaefile build should inherit the options for
    // the actual build at all.
    auto newOptions = options.dup;
    newOptions.backend = Backend.binary;
    newOptions.dubObjsDir = dubObjsDir;
    newOptions.projectPath = dubRecipeDir;
    newOptions.workingDir = dubRecipeDir;

    auto build = Build(dubPackage(newOptions, DubPath(dubRecipeDir)));

    runtimeBuild(newOptions, build);

    return getBuildGenName(options);
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
    if(options.verbose)
        output.log(res.output);
}

private string[] importPaths(in Options options) @safe nothrow {
    import std.file: exists;
    import std.algorithm: map;
    import std.array: array;
    import std.range: chain, only;
    import std.path: buildPath;

    auto imports = chain(only(reggaeSrcDirName(options)), options.reggaefileImportPaths)
        .map!(p => "-I" ~ p)
        .array;
    auto projPathImport = "-I" ~ options.projectPath;
    // if compiling phobos, the includes for the reggaefile.d compilation
    // will pick up the new phobos if we include the src path
    return "std".exists ? imports : projPathImport ~ imports;
}

private string getBuildGenName(in Options options) @safe pure nothrow {
    import reggae.rules.common: exeExt;
    import std.path: buildPath;

    const baseName =  options.backend == Backend.binary
        ? "../build"
        : "buildgen";

    return buildPath(hiddenDirAbsPath(options), baseName) ~ exeExt;
}

// On Windows we're apparently not allowed to have a main function in
// a static library so we have to build the main function with the
// reggaefile
private enum buildGenMainSrc =
q{
    // args is empty except for the binary backend,
    // in which case it's used for runtime options
    int main(string[] args) {
        try {
            import reggae.config: options;
            import reggae.buildgen: doBuildFor;
            doBuildFor!("reggaefile")(options, args); //the user's build description
            return 0;
        } catch(Exception ex) {
            import std.stdio: stderr;
            stderr.writeln(ex.msg);
            return 1;
        }
    }
};

private void writeSrcFiles(T)(auto ref T output, in Options options) {
    import reggae.io: log;
    import std.file: mkdirRecurse, rmdirRecurse, exists;
    import std.path: dirName;

    writeIfDiffers(
        output,
        buildGenMainSrcPath(options),
        buildGenMainSrc,
    );

    if(!haveToWriteSrcFiles(options))
        return;

    output.log("Writing reggae source files");

    immutable reggaePkgDirName = reggaePkgDirName(options);

    // FIXME: only write what's necessary, delete files that are no
    // longer needed.
    if(reggaePkgDirName.exists)
        rmdirRecurse(reggaePkgDirName);

    enum fileNames = mixin(import("payload.txt"));
    // this foreach has to happen at compile time due
    // to the string import below.
    foreach(fileName; aliasSeqOf!fileNames) {
        const filePath = reggaeSrcFileName(options, fileName);

        if(!filePath.dirName.exists)
            mkdirRecurse(filePath.dirName);

        auto file = File(filePath, "w");
        file.write(import(fileName));
    }
}

private bool haveToWriteSrcFiles(in Options options) {
    import std.file: readText, dirEntries, SpanMode, exists;
    import std.algorithm: map, filter, sort, endsWith;
    import std.array: join, array;
    import std.meta: staticMap, aliasSeqOf;

    immutable reggaePkgDirName = reggaePkgDirName(options);

    if(!reggaePkgDirName.exists)
        return true;

    enum read(string fileName) = import(fileName);
    enum fileNames = mixin(import("payload.txt"))
        .filter!(a => !a.endsWith("config.d"))
        .array
        .sort
        .array;
    enum whatIHaves = staticMap!(read, aliasSeqOf!(fileNames));
    enum whatIHave = [whatIHaves].join; // concat of all files

    const whatsThere = dirEntries(reggaePkgDirName, SpanMode.breadth)
        .filter!(de => !de.isDir)
        .filter!(a => !a.name.endsWith("config.d"))
        .array
        .sort
        .map!(de => de.name.readText.dos2unix)
        .join;

    return whatIHave != whatsThere;
}

private void writeConfig(T)(auto ref T output, in Options options) {

    import reggae.io: log;
    import std.file: readText;

    version(minimal) {
        static void dubConfigSource(A...)(auto ref A args) { return ""; }
    } else {
        import reggae.dub.interop: dubConfigSource;
    }

    const reggaeSrc = reggaeConfigSource(options);
    const dubSrc = dubConfigSource(output, options);
    const src = reggaeSrc ~ dubSrc;
    const fileName = reggaeSrcFileName(options, "config.d");

    // for "reasons", using strEqModNewLine breaks on Windows
    if(fileName.readText.dos2unix == src)
        return;

    output.log("Writing reggae configuration");

    auto file = File(fileName, "w");
    file.write(src);
}

// the text of the config.d file to be written
private string reggaeConfigSource(in Options options) @safe {

    string ret;

    void append(A...)(auto ref A args) {
        import std.conv: text;
        ret ~= text(args, "\n");
    }

    append(q{
module reggae.config;
import reggae.ctaa;
import reggae.types;
import reggae.options;
    });

    version(minimal) append("enum isDubProject = false;");
    append("immutable options = ", options, ";");

    append("enum userVars = AssocList!(string, string)([");
    foreach(key, value; options.userVars) {
        append("assocEntry(`", key, "`, `", value, "`), ");
    }
    append("]);");

    return ret;
}

public string dubObjsDir() @safe {
    import std.path: buildPath;
    import std.file: tempDir;
    // don't ask
    static string ret;
    if(ret == ret.init)
        ret = buildPath(tempDir, "reggae");
    return ret;
}

private string reggaeSrcFileName(in Options options, in string fileName) @safe pure nothrow {
    import std.path: buildPath;
    return buildPath(reggaePkgDirName(options), fileName);
}

private string reggaePkgDirName(in Options options) @safe pure nothrow {
    import std.path: buildPath;
    return buildPath(reggaeSrcDirName(options), "reggae");
}

private string reggaeSrcDirName(in Options options) @safe pure nothrow {
    import std.path: buildPath;
    return buildPath(hiddenDirAbsPath(options), "packages", "reggae", "source");
}

private string hiddenDirAbsPath(in Options options) @safe pure nothrow {
    import reggae.options: hiddenDir;
    import std.path: buildPath;

    return buildPath(options.workingDir, hiddenDir);
}

private string buildGenMainSrcPath(in Options options) @safe pure nothrow {
    import std.path: buildPath;
    return buildPath(hiddenDirAbsPath(options), "buildgen_main.d");
}

private bool strEqModNewLine(in string lhs, in string rhs) @safe pure nothrow {
    return lhs.dos2unix == rhs.dos2unix;
}

private string dos2unix(in string str) @safe pure nothrow {
    import std.array: replace;
    return str.replace("\r\n", "\n");
}
