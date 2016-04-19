module tests.it;

import reggae;

immutable string origPath;

shared static this() {
    import std.file;
    import std.path;
    import std.algorithm;
    import std.range;

    auto paths = [".", ".."].map!(a => buildNormalizedPath(getcwd, a)).find!(a => buildNormalizedPath(a, "dub.json").exists);
    assert(!paths.empty, "Error: Cannot find reggae top dir using dub.json");
    origPath = paths.front.absolutePath;
    if(testPath.exists) rmdirRecurse(testPath);
    mkdirRecurse(testPath);
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

extern(C) char* mkdtemp(char*);

string newTestDir() {
    import std.conv;
    import std.path;
    import std.algorithm;

    char[100] template_;
    std.algorithm.copy(buildPath(testPath, "XXXXXX") ~ '\0', template_[]);
    auto ret = mkdtemp(&template_[0]).to!string;

    return ret;
}

Options testOptions(string[] args) {
    auto testPath = newTestDir;
    return getOptions(["reggae", "-C", testPath] ~ args);
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
    return [buildPath(path, "build"), "--norerun"] ~ args;
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
void doTestBuildFor(alias module_ = __MODULE__)(Options options, string[] args = []) {
    import tests.utils;
    import std.file;
    import std.string;
    import std.path;

    // tup needs special treatment - it's ok with absolute file paths
    // but only if relative to the build path, so copy the project files
    // to the build directory
    if(options.backend == Backend.tup) {
        immutable projectsPath = buildPath(origPath, "tests", "projects");
        immutable projectName = module_.split(".")[0];
        immutable projectPath = buildPath(projectsPath, projectName);

        // change the directory of the project to be where the build dir is
        options.projectPath = buildPath(origPath, (options.workingDir).relativePath(origPath));
        auto modulePath = buildPath(projectsPath, module_.split(".").join(dirSeparator));

        // copy all project files over to the build directory
        foreach(entry; dirEntries(dirName(modulePath), SpanMode.depth)) {
            if(entry.isDir) continue;
            auto tgtName = buildPath(options.workingDir, entry.relativePath(projectPath));
            auto dir = dirName(tgtName);
            if(!dir.exists) mkdirRecurse(dir);
            copy(entry, buildPath(options.workingDir, tgtName));
        }
    }

    auto cmdArgs = buildCmd(options.backend, options.workingDir, args);
    doBuildFor!module_(options, cmdArgs);
    if(options.backend != Backend.binary)
        cmdArgs.shouldExecuteOk(options.workingDir);

}
