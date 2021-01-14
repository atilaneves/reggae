module reggae.sorting;


import std.range: isInputRange;


string[][] byPackage(R)(R files) if(isInputRange!R) {

    string[][string] packageToFiles;

    foreach(file; files) {
        auto package_ = file.filePackage;
        if(package_ !in packageToFiles) packageToFiles[package_] = [];
        packageToFiles[package_] ~= file;
    }

    return () @trusted { return packageToFiles.values; }();
}

private string filePackage(string path) @safe pure nothrow {
    import std.array: join;
    return path.packageParts.join(".");
}


/**
    Returns the path of the package corresponding to a file name.
 */
string packagePath(in string fileName) @safe pure {
    import std.algorithm: reduce;
    import reggae.path: buildPath;
    return fileName.packageParts.reduce!((a, b) => buildPath(a, b));
}

private string[] packageParts(string path) @safe pure nothrow {
    import std.path: pathSplitter;
    import std.array: array;
    return () @trusted { return cast(string[]) path.pathSplitter.array[0 .. $-1]; }();
}
