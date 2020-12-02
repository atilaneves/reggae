module reggae.dub.interop.fetch;


import reggae.from;


package void dubFetch(T)(auto ref T output,
                         in from!"reggae.options".Options options)
    @trusted
{
    import reggae.dub.interop.exec: callDub, dubEnvArgs;
    import reggae.io: log;
    import std.array: replace;
    import std.path: buildPath;
    import std.json: parseJSON, JSONType;
    import std.file: readText, exists;
    import std.parallelism: parallel;

    const fileName = buildPath(options.projectPath, "dub.selections.json");
    if(!fileName.exists) {
        output.log("Creating dub.selections.json");
        const cmd = ["dub", "upgrade"] ~ dubEnvArgs;
        callDub(output, options, cmd);
    }

    auto json = parseJSON(readText(fileName));
    auto versions = json["versions"];

    static struct VersionedPackage {
        string name;
        string version_;
    }

    VersionedPackage[] pkgsToFetch;

    foreach(dubPackage, versionJson; versions.object) {

        // skip the ones with a defined path
        if(versionJson.type != JSONType.string) continue;

        // versions are usually `==1.2.3`, so strip the equals sign
        const version_ = versionJson.str.replace("==", "");

        if(needDubFetch(options, dubPackage, version_))
            pkgsToFetch ~= VersionedPackage(dubPackage, version_);
    }

    foreach(pkg; pkgsToFetch.parallel) {
        const cmd = ["dub", "fetch", pkg.name, "--version=" ~ pkg.version_] ~ dubEnvArgs;
        callDub(output, options, cmd);
    }
}


private bool needDubFetch(
    in from!"reggae.options".Options options,
    in string dubPackage,
    in string version_)
    @safe
{
    import reggae.dub.interop.dublib: getPackage;

    // first check the file system explicitly
    if(pkgExistsOnFS(dubPackage, version_)) return false;
    // next ask dub (this is slower)
    if(getPackage(options, dubPackage, version_)) return false;

    return true;
}


// dub fetch can sometimes take >10s (!) despite the package already being
// on disk
private bool pkgExistsOnFS(in string dubPackage, in string version_) @safe {
    import reggae.path: dubPackagesDir;
    import std.path: buildPath;
    import std.file: exists;

    return buildPath(
        dubPackagesDir,
        dubPackage ~ "-" ~ version_,
        dubPackage ~ ".lock"
    ).exists;
}
