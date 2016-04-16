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
    return buildPath(tempDir, "reggae");
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
