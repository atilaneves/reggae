module reggae.path;

// Uses std.path.buildPath to combine segments to a path.
// Additionally, on Windows, all forward slashes are replaced by backslashes.
string buildPath(scope string[] segments...) @safe pure nothrow {
    import std.path : buildPath, dirSeparator;
    string r = segments.length == 1 ? segments[0] : buildPath(segments);
    version (Windows)
    {
        import std.array: replace;
        r = r.replace("/", dirSeparator);
    }
    return r;
}

string deabsolutePath(in string path) @safe pure nothrow {
    import std.path: isRooted, stripDrive;
    return path.isRooted
        ? path.stripDrive[1..$]
        : path;
}
