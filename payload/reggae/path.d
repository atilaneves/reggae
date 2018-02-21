module reggae.path;

string deabsolutePath(in string path) @safe pure {
    import std.path: isAbsolute;
    version(Windows) throw new Exception("not implemented yet");
    return path.isAbsolute
        ? path[1..$]
        : path;
}
