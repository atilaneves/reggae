module reggae.dub.interop.fetch;


import reggae.from;


package void dubFetch(O)(
    auto ref O output,
    ref from!"reggae.dub.interop.dublib".Dub dub,
    in from!"reggae.options".Options options)
    @trusted
{
    import reggae.dub.interop.exec: callDub, dubEnvArgs;
    import std.array: replace;
    import std.json: parseJSON, JSONType;
    import std.file: readText;
    import std.parallelism: parallel;

    static struct VersionedPackage {
        string name;
        string version_;
    }

    VersionedPackage[] pkgsToFetch;
    const json = parseJSON(readText(dubSelectionsJson(output, options)));

    foreach(dubPackage, versionJson; json["versions"].object) {

        // skip the ones with a defined path
        if(versionJson.type != JSONType.string) continue;

        // versions are usually `==1.2.3`, so strip the equals sign
        const version_ = versionJson.str.replace("==", "");

        if(needDubFetch(dub, dubPackage, version_))
            pkgsToFetch ~= VersionedPackage(dubPackage, version_);
    }

    foreach(pkg; pkgsToFetch.parallel) {
        const cmd = ["dub", "fetch", pkg.name, "--version=" ~ pkg.version_] ~ dubEnvArgs;
        callDub(output, options, cmd);
    }
}


private string dubSelectionsJson(O)(ref O output, in from!"reggae.options".Options options) @safe {

    import reggae.dub.interop.exec: callDub, dubEnvArgs;
    import reggae.io: log;
    import std.path: buildPath;
    import std.file: exists;
    import std.exception: enforce;

    const path = buildPath(options.projectPath, "dub.selections.json");

    if(!path.exists) {
        output.log("Creating dub.selections.json");
        const cmd = ["dub", "upgrade"] ~ dubEnvArgs;
        callDub(output, options, cmd);
    }

    enforce(path.exists, "Could not create dub.selections.json");

    return path;
}


private bool needDubFetch(
    ref from!"reggae.dub.interop.dublib".Dub dub,
    in string dubPackage,
    in string version_)
    @safe
{
    // first check the file system explicitly
    if(pkgExistsOnFS(dubPackage, version_)) return false;
    // next ask dub (this is slower)
    if(dub.getPackage(dubPackage, version_)) return false;

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
