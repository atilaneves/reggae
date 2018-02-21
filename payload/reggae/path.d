module reggae.path;

string deabsolutePath(in string path) @safe pure {
    import std.path: isAbsolute;
    version(Windows) throw new Exception("not implemented yet");
    return path.isAbsolute
        ? path[1..$]
        : path;
}


string dubPackagesDir() @safe {

    import std.path: buildPath;
    import std.process: environment;

    version(Windows)
        return buildPath("C:\\Users", environment["USERNAME"], "AppData", "Roaming", "dub", "packages");
    else
        return buildPath(environment["HOME"], ".dub", "packages");

}
