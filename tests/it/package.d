module tests.it;

import reggae;

immutable string origPath;

shared static this() {
    import std.file;
    import std.path;
    import std.algorithm;
    import std.range;
    import std.stdio: writeln;

    auto paths = [".", ".."].map!(a => buildNormalizedPath(getcwd, a)).find!(a => buildNormalizedPath(a, "dub.json").exists);
    assert(!paths.empty, "Error: Cannot find reggae top dir using dub.json");
    origPath = paths.front.absolutePath;

    if(testPath.exists) {
        writeln("[IT] Removing old test path");
        foreach(entry; dirEntries(testPath, SpanMode.shallow)) {
            if(isDir(entry.name)) {
                rmdirRecurse(entry);
            }
        }
    }

    writeln("[IT] Creating new test path");
    mkdirRecurse(testPath);

    buildDCompile();
}

private void buildDCompile() {
    import std.meta;
    import std.process;
    import std.exception;
    import std.conv;
    import std.array;
    import std.stdio: writeln;
    import std.algorithm: any;
    import reggae.file;

    enum fileNames = ["dcompile.d", "dependencies.d"];

    immutable needToRecompile = fileNames.
        any!(a => buildPath(origPath, "payload", "reggae", a).newerThan(buildPath(testPath, a)));

    if(!needToRecompile)
        return;

    writeln("[IT] Building dcompile");

    foreach(fileName; aliasSeqOf!fileNames) {
        writeFile!fileName;
    }

    enum args = ["dmd", "-ofdcompile"] ~ fileNames;
    const string[string] env = null;
    Config config = Config.none;
    size_t maxOutput = size_t.max;
    const workDir = testPath;

    immutable res = execute(args, env, config, maxOutput, workDir);
    enforce(res.status == 0, text("Could not execute '", args.join(" "), "':\n", res.output));
}

private void writeFile(string fileName)() {
    import std.stdio;
    import std.path;
    auto file = File(buildPath(testPath, fileName), "w");
    file.write(import(fileName));
}


string testPath() @safe {
    import std.file;
    import std.path;
    return buildNormalizedPath(origPath, "tmp");
}


string inOrigPath(T...)(T parts) {
    return inPath(origPath, parts);
}

string inPath(T...)(string path, T parts) {
    import std.path;
    return buildPath(path, parts).absolutePath;
}

string projectPath(in string name) {
    import std.path;
    return inOrigPath("tests", "projects", name);
}

extern(C) char* mkdtemp(char*);

string newTestDir() {
    import std.conv;
    import std.path;
    import std.algorithm;

    char[100] template_;
    std.algorithm.copy(buildPath(testPath, "XXXXXX") ~ '\0', template_[]);
    auto ret = mkdtemp(&template_[0]).to!string;

    return ret.absolutePath;
}

Options testOptions(string[] args) {
    import reggae.config: setOptions;
    auto options = getOptions(["reggae", "-C", newTestDir] ~ args);
    setOptions(options);
    return options;
}

Options testProjectOptions(in string backend, in string projectName) {
    return testOptions(["-b", backend, projectPath(projectName)]);
}

// used to change files and cause a rebuild
void overwrite(in Options options, in string fileName, in string newContents) {
    import core.thread;
    import std.stdio;
    import std.path;

    // ninja has problems with timestamp differences that are less than a second apart
    if(options.backend == Backend.ninja) {
        Thread.sleep(1.seconds);
    }

    auto file = File(buildPath(options.workingDir, fileName), "w");
    file.writeln(newContents);
}

string[] ninja(string[] args = []) {
    return ["ninja", "-j1"] ~ args;
}

string[] make(string[] args = []) {
    return ["make"] ~ args;
}

string[] tup(string[] args = []) {
    return ["tup"] ~ args;
}

string[] binary(string path, string[] args = []) {
    import std.path;
    return [buildPath(path, "build"), "--norerun", "--single"] ~ args;
}

string[] buildCmd(in Options options, string[] args = []) {
    return buildCmd(options.backend, options.workingDir, args);
}

string[] buildCmd(Backend backend, string path, string[] args = []) {
    final switch(backend) {
    case Backend.ninja:
        return ninja(args);
    case Backend.make:
        return make(args);
    case Backend.tup:
        return tup(args);
    case Backend.binary:
        return binary(path, args);
    case Backend.none:
        return [];
    }
}

// do a build in the integration test context
// this uses the build description to generate the build
// then runs the build command
void doTestBuildFor(string module_ = __MODULE__)(ref Options options, string[] args = []) {
    prepareTestBuild!module_(options);
    justDoTestBuild!module_(options, args);
}

void prepareTestBuild(string module_ = __MODULE__)(ref Options options) {
    import std.file;
    import std.string;
    import std.path;
    import std.algorithm: canFind;

    mkdirRecurse(buildPath(options.workingDir, ".reggae"));
    symlink(buildPath(testPath, "dcompile"), buildPath(options.workingDir, ".reggae", "dcompile"));

    // copy the project files over, that way the tests can modify them
    immutable projectsPath = buildPath(origPath, "tests", "projects");
    immutable projectName = module_.split(".")[0];
    immutable projectPath = buildPath(projectsPath, projectName);

    // change the directory of the project to be where the build dir is
    options.projectPath = buildPath(origPath, (options.workingDir).relativePath(origPath));
    auto modulePath = buildPath(projectsPath, module_.split(".").join(dirSeparator));

    // copy all project files over to the build directory
    if(module_.canFind("reggaefile")) {
        foreach(entry; dirEntries(dirName(modulePath), SpanMode.depth)) {
            if(entry.isDir) continue;
            auto tgtName = buildPath(options.workingDir, entry.relativePath(projectPath));
            auto dir = dirName(tgtName);
            if(!dir.exists) mkdirRecurse(dir);
            copy(entry, buildPath(options.workingDir, tgtName));
        }
        options.projectPath = options.workingDir;
    }
}

void justDoTestBuild(string module_ = __MODULE__)(in Options options, string[] args = []) {
    import tests.utils;

    auto cmdArgs = buildCmd(options, args);
    doBuildFor!module_(options, cmdArgs); // generate build
    if(options.backend != Backend.binary)
        cmdArgs.shouldExecuteOk(options.workingDir);
}

void buildCmdShouldRunOk(alias module_ = __MODULE__)(in Options options, string[] args = [],
                                                     string file = __FILE__, ulong line = __LINE__ ) {
    import tests.utils;
    auto cmdArgs = buildCmd(options, args);
    // the binary backend in the tests isn't a separate executable, but make, ninja and tup are
    options.backend == Backend.binary
        ? doBuildFor!module_(options, cmdArgs)
        : cmdArgs.shouldExecuteOk(options.workingDir, file, line);
}
