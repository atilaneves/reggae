module tests.it;

import reggae;

immutable string origPath;

shared static this() {
    import std.file;
    import std.path;
    origPath = getcwd.absolutePath;
    if(testPath.exists) rmdirRecurse(testPath);
    mkdirRecurse(testPath);
}


string testPath() @safe {
    import std.file;
    import std.path;
    return buildPath(origPath, "tmp");
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
        throw new Exception("No buildCmd for none");
    }
}


void doTestBuildFor(alias module_ = __MODULE__)(in Options options, string[] args = []) {
    import tests.utils;
    auto cmdArgs = buildCmd(options.backend, options.workingDir, args);
    doBuildFor!module_(options, cmdArgs);
    if(options.backend != Backend.binary)
        cmdArgs.shouldExecuteOk(options.workingDir);

}
