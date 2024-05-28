module tests.it;

public import reggae;
public import unit_threaded;
import reggae.path: buildPath;

immutable string origPath;

shared static this() nothrow {
    import std.file: mkdirRecurse, rmdirRecurse, getcwd, dirEntries, SpanMode, exists, isDir;
    import std.path: buildNormalizedPath, absolutePath;
    import std.algorithm: map, find;

    try {
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

    } catch(Exception e) {
        import std.stdio: stderr;
        try
            stderr.writeln("Shared static ctor failed: ", e);
        catch(Exception e2) {
            import core.stdc.stdio;
            printf("Shared static ctor failed\n");
        }
    }
}

private void writeFile(string fileName)() {
    import std.stdio;
    auto file = File(buildPath(testsPath, fileName), "w");
    file.write(import(fileName));
}


string testsPath() @safe {
    import std.path: buildNormalizedPath;
    return buildNormalizedPath(origPath, "tmp");
}


string inOrigPath(T...)(T parts) {
    return inPath(origPath, parts);
}

string inPath(T...)(in string path, T parts) {
    import std.path: absolutePath;
    return buildPath(path, parts).absolutePath;
}

string inPath(T...)(in Options options, T parts) {
    return inPath(options.workingDir, parts);
}


string projectPath(in string name) {
    return inOrigPath("tests", "projects", name);
}

string newTestDir() {
    import unit_threaded.integration: uniqueDirName;
    return uniqueDirName(testsPath);
}

Options testOptions(string[] args) {
    import reggae.config: setOptions;
    auto options = getOptions(["reggae", "-C", newTestDir] ~ args);
    setOptions(options);
    return options;
}

Options testProjectOptions(string module_)(string backend) {
    import std.string;
    return testProjectOptions(backend, module_.split(".")[0]);
}

Options testProjectOptions(in string backend, in string projectName) {
    return testOptions(["-b", backend, projectPath(projectName)]);
}

// used to change files and cause a rebuild
void overwrite(in Options options, in string fileName, in string newContents) {
    import core.thread;
    import std.stdio;

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
    import std.file: mkdirRecurse;
    import std.string;
    import std.path: dirSeparator, relativePath;
    import std.algorithm: canFind;
    import reggae.config;

    mkdirRecurse(buildPath(options.workingDir, ".reggae"));

    // copy the project files over, that way the tests can modify them
    immutable projectsPath = buildPath(origPath, "tests/projects");
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
    import std.path: dirName, relativePath;
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
