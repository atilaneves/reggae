module tests.it;


immutable string origPath;

shared static this() {
    import std.file;
    import std.path;
    origPath = getcwd.absolutePath;
    testPath.exists || mkdir(testPath);
    chdir(testPath);
}


string testPath() @safe {
    import std.file;
    import std.path;
    return buildPath(tempDir, "reggae");
}

string inTestPath(T...)(T parts) {
    return inPath(testPath, parts);
}

string inOrigPath(T...)(T parts) {
    return inPath(origPath, parts);
}

string inPath(T...)(string path, T parts) {
    import std.path;
    return buildPath(path, parts).absolutePath;
}
