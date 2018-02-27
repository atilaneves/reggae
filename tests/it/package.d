module tests.it;

public import reggae;
public import unit_threaded;

immutable string origPath;

shared static this() {
    import std.file: mkdirRecurse, rmdirRecurse, getcwd, dirEntries, SpanMode, exists, isDir;
    import std.path: buildNormalizedPath, absolutePath;
    import std.algorithm: map, find;

    auto paths = [".", ".."].map!(a => buildNormalizedPath(getcwd, a))
        .find!(a => buildNormalizedPath(a, "dub.json").exists);
    assert(!paths.empty, "Error: Cannot find reggae top dir using dub.json");
    origPath = paths.front.absolutePath;

    if(testsPath.exists) {
        writelnUt("[IT] Removing old test path ", testsPath);
        foreach(entry; dirEntries(testsPath, SpanMode.shallow)) {
            if(isDir(entry.name)) {
                rmdirRecurse(entry);
            }
        }
    }

    writelnUt("[IT] Creating new test path ", testsPath);
    mkdirRecurse(testsPath);

    buildDCompile();
}

private void buildDCompile() {
    import std.meta: aliasSeqOf;
    import std.exception: enforce;
    import std.conv: text;
    import std.stdio: writeln;
    import std.algorithm: any;
    import std.file: exists;
    import std.path: buildPath;
    import std.process: execute, Config;
    import std.array: join;
    import reggae.file;

    enum fileNames = ["dcompile.d", "dependencies.d"];

    const exeName = buildPath("tmp", "dcompile");
    immutable needToRecompile =
        !exeName.exists ||
        fileNames.
        any!(a => buildPath(origPath, "payload", "reggae", a).
        newerThan(buildPath(testsPath, a)));

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
    const workDir = testsPath;

    immutable res = execute(args, env, config, maxOutput, workDir);
    enforce(res.status == 0, text("Could not execute '", args.join(" "), "':\n", res.output));
}

private void writeFile(string fileName)() {
    import std.stdio;
    import std.path;
    auto file = File(buildPath(testsPath, fileName), "w");
    file.write(import(fileName));
}


string testsPath() @safe {
    import std.file;
    import std.path;
    return buildNormalizedPath(origPath, "tmp");
}


string inOrigPath(T...)(T parts) {
    return inPath(origPath, parts);
}

string inPath(T...)(in string path, T parts) {
    import std.path;
    return buildPath(path, parts).absolutePath;
}

string inPath(T...)(in Options options, T parts) {
    return inPath(options.workingDir, parts);
}


string projectPath(in string name) {
    import std.path;
    return inOrigPath("tests", "projects", name);
}

version(Posix)
    extern(C) char* mkdtemp(char*);
else
    char* mkdtemp(char*) {
        throw new Exception("No mkdtemp function on Windows");
    }

string newTestDir() {
    import std.conv;
    import std.path;
    import std.algorithm;

    char[100] template_;
    std.algorithm.copy(buildPath(testsPath, "XXXXXX") ~ '\0', template_[]);
    auto ret = mkdtemp(&template_[0]).to!string;

    return ret.absolutePath;
}

@DontTest
Options testOptions(string[] args) {
    import reggae.config: setOptions;
    auto options = getOptions(["reggae", "-C", newTestDir] ~ args);
    setOptions(options);
    return options;
}

Options _testProjectOptions(in string backend, in string projectName) {
    return testOptions(["-b", backend, projectPath(projectName)]);
}

Options _testProjectOptions(in string projectName) {
    return testOptions(["-b", getValue!string, projectPath(projectName)]);
}

Options _testProjectOptions(string module_)() {
    import std.string;
    return _testProjectOptions(module_.split(".")[0]);
}

Options _testProjectOptions(string module_)(string backend) {
    import std.string;
    return _testProjectOptions(backend, module_.split(".")[0]);
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

// used to change files and cause a rebuild
void overwrite(in string fileName, in string newContents) {
    import reggae.config;
    overwrite(options, fileName, newContents);
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
    version(Windows) {
        assert(false);
    } else {
        import std.file: symlink;
        import std.string;
        import std.path;
        import std.algorithm: canFind;
        import reggae.config;

        mkdirRecurse(buildPath(options.workingDir, ".reggae"));
        symlink(buildPath(testsPath, "dcompile"), buildPath(options.workingDir, ".reggae", "dcompile"));

        // copy the project files over, that way the tests can modify them
        immutable projectsPath = buildPath(origPath, "tests", "projects");
        immutable projectName = module_.split(".")[0];
        immutable projectPath = buildPath(projectsPath, projectName);

        // change the directory of the project to be where the build dir is
        options.projectPath = buildPath(origPath, (options.workingDir).relativePath(origPath));
        auto modulePath = buildPath(projectsPath, module_.split(".").join(dirSeparator));

        // copy all project files over to the build directory
        if(module_.canFind("reggaefile")) {
            copyProjectFiles(projectPath, options.workingDir);
            options.projectPath = options.workingDir;
        }

        setOptions(options);
    }
}

void justDoTestBuild(string module_ = __MODULE__)(in Options options, string[] args = []) {
    import tests.utils;

    auto cmdArgs = buildCmd(options, args);
    doBuildFor!module_(options, cmdArgs); // generate build
    if(options.backend != Backend.binary && options.backend != Backend.none)
        cmdArgs.shouldExecuteOk(WorkDir(options.workingDir));
}

string[] buildCmdShouldRunOk(alias module_ = __MODULE__)(in Options options,
                                                         string[] args = [],
                                                         string file = __FILE__,
                                                         size_t line = __LINE__ ) {
    import tests.utils;
    auto cmdArgs = buildCmd(options, args);

    string[] doTheBuild() {
        doBuildFor!module_(options, cmdArgs);
        return [];
    }

    // the binary backend in the tests isn't a separate executable, but make, ninja and tup are
    return options.backend == Backend.binary
        ? doTheBuild
        : cmdArgs.shouldExecuteOk(WorkDir(options.workingDir), file, line);
}

// copy one of the test projects to a temporary test directory
void copyProjectFiles(in string projectPath, in string testPath) {
    import std.file;
    import std.path;
    foreach(entry; dirEntries(projectPath, SpanMode.depth)) {
        if(entry.isDir) continue;
        auto tgtName = buildPath(testPath, entry.relativePath(projectPath));
        auto dir = dirName(tgtName);
        if(!dir.exists) mkdirRecurse(dir);
        copy(entry, buildPath(testPath, tgtName));
    }
}

// whether a file exists in the test sandbox
void shouldNotExist(string fileName, string file = __FILE__, size_t line = __LINE__) {
    import reggae.config;
    import std.file;

    fileName = inPath(options, fileName);
    if(fileName.exists) {
        throw new UnitTestException(["File " ~ fileName ~ " was not expected to exist but does"]);
    }
}
