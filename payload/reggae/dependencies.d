module reggae.dependencies;


// Get a D file's dependencies from a file generated with
// -makedeps=$filename
string[] parseDepFile(in string fileName) @safe {
    import std.string: chomp;
    import std.algorithm: splitter, filter, canFind, among;
    import std.array: array;
    import std.file: readText, exists;
    import std.string: replace;
    import std.path: buildPath, baseName, extension;

    if(!fileName.exists) return [];

    const text = readText(fileName);

    // The file is going to be like this: `foo.o: foo.d`, but possibly
    // with arbitrary backslashes to extend the line
    return text
        .chomp
        .replace("\\\n", "")
        .splitter(" ")
        .filter!(a => a != "")
        .filter!(a => a.extension.among(".d", ".di"))
        .filter!(a => a.baseName != "object.d")
        .filter!(a => !a.canFind(buildPath("src", "reggae", ""))) // ignore reggae files
        .filter!(a => !a.isStdLib)
        .array[1..$] // ignore the object file *and* the source file
        ;
}

private bool isStdLib(in string path) @safe pure nothrow {
    import std.path: dirSeparator;
    import std.algorithm: canFind, any;
    import std.range: only;

    bool isIn(in string containing) {
        return path.canFind(dirSeparator ~ containing ~ dirSeparator);
    }

    return only("std", "core", "etc", "ldc").any!isIn;
}
