module reggae.dub.interop.fetch;


import reggae.from;


package void dubFetch(O)(
    auto ref O output,
    ref from!"reggae.dub.interop.dublib".Dub dub,
    in from!"reggae.options".Options options,
    in string dubSelectionsJson)
    @trusted
{
    import reggae.dub.interop.exec: callDub, dubEnvArgs;
    import reggae.io: log;
    import std.array: replace;
    import std.json: parseJSON, JSONType;
    import std.file: readText;
    import std.parallelism: parallel;

    const(VersionedPackage)[] pkgsToFetch;

    const json = parseJSON(readText(dubSelectionsJson));

    foreach(dubPackageName, versionJson; json["versions"].object) {

        // skip the ones with a defined path
        if(versionJson.type != JSONType.string) continue;

        // versions are usually `==1.2.3`, so strip the equals sign
        const version_ = versionJson.str.replace("==", "");
        const pkg = VersionedPackage(dubPackageName, version_);

        if(needDubFetch(dub, pkg)) pkgsToFetch ~= pkg;
    }

    output.log("Fetching dub packages");
    foreach(pkg; pkgsToFetch.parallel) {
        const cmd = ["dub", "fetch", pkg.name, "--version=" ~ pkg.version_] ~ dubEnvArgs;
        callDub(output, options, cmd);
    }

    output.log("Reloading project");
    dub.reinit;
    output.log("Project reloaded");
}


private struct VersionedPackage {
    string name;
    string version_;
}


private bool needDubFetch(
    ref from!"reggae.dub.interop.dublib".Dub dub,
    in VersionedPackage pkg)
    @safe
{
    // first check the file system explicitly
    if(pkgExistsOnFS(pkg)) return false;
    // next ask dub (this is slower)
    if(dub.getPackage(pkg.name, pkg.version_)) return false;

    return true;
}


// dub fetch can sometimes take >10s (!) despite the package already being
// on disk
private bool pkgExistsOnFS(in VersionedPackage pkg) @safe {
    import reggae.path: dubPackagesDir;
    import std.path: buildPath;
    import std.file: exists;
    import std.string: replace;

    // Some versions include a `+` and that becomes `_` in the path
    const version_ = pkg.version_.replace("+", "_");

    return buildPath(
        dubPackagesDir,
        pkg.name ~ "-" ~ version_,
        pkg.name ~ ".lock"
    ).exists;
}
