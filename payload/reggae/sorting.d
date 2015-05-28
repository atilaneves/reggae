module reggae.sorting;

import std.range: isInputRange;
import std.path: pathSplitter;
import std.array: array;

@safe:


private string[] packageParts(string path) pure nothrow {
    return () @trusted { return cast(string[])path.pathSplitter.array[0 .. $-1]; }();
}

private string filePackage(string path) pure nothrow {
    import std.array: join;
    return path.packageParts.join(".");
}


auto byPackage(R)(R files) if(isInputRange!R) {
    string[][string] packageToFiles;
    foreach(file; files) {
        auto package_ = file.filePackage;
        if(package_ !in packageToFiles) packageToFiles[package_] = [];
        packageToFiles[package_] ~= file;
    }
    return () @trusted { return packageToFiles.values; }();
}
