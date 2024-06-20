/**
   Rules for building "external" dub packages, i.e. dub dependencies.
 */
module reggae.rules.dub.external;

/**
   A dub path-based dependency. The value should be a path to a dub
   package on the filesystem.
 */
struct DubPath {
    import reggae.types: Configuration;
    string value;
    Configuration config;
}

/*
  A dub version-based dependency.
 */
struct DubVersion {
    import reggae.types: Configuration;
    string name;
    string version_;
    Configuration config;
}

/**
   The types of binaries that a target that has dub dependencies (but
   isn't a dub package itself) can have.
 */
enum DubPackageTargetType {
    executable,
    sharedLibrary,
    staticLibrary,
}


imported!"reggae.build".Target dubPackage(DubPath dubPath)() {
    import reggae.config: reggaeOptions = options; // the ones used to run reggae
    return dubPackage(reggaeOptions, dubPath);
}

imported!"reggae.build".Target dubPackage(in imported!"reggae.options".Options options, in DubPath dubPath) {
    return DubPathDependency(options, dubPath).target;
}

imported!"reggae.build".Target dubPackage(DubVersion dubVersion)() {
    import reggae.config: reggaeOptions = options; // the ones used to run reggae
    return dubPackage(reggaeOptions, dubVersion);
}

imported!"reggae.build".Target dubPackage(in imported!"reggae.options".Options options, in DubVersion dubVersion) {
    return DubPathDependency(options, dubVersion).target;
}

/**
   A target that depends on dub packages but isn't one itself.
 */
imported!"reggae.build".Target dubDependant(
    imported!"reggae.types".TargetName targetName,
    DubPackageTargetType targetType,
    alias sourcesFunc,
    // the other arguments can be:
    // * DubPath
    // * DubVersion
    // * CompilerFlags
    // * LinkerFlags
    // * ImportPaths
    // * StringImportPaths
    A...
    )
    ()
{
    import reggae.config: reggaeOptions = options; // the ones used to run reggae
    return dubDependant!sourcesFunc(reggaeOptions, targetName, targetType, A);
}

// mostly runtime version
imported!"reggae.build".Target dubDependant
    (alias sourcesFunc, A...)
    (
        in imported!"reggae.options".Options options,
        in imported!"reggae.types".TargetName targetName,
        DubPackageTargetType targetType,
        // the other arguments can be:
        // * DubPath
        // * DubVersion
        // * CompilerFlags
        // * LinkerFlags
        // * ImportPaths
        // * StringImportPaths
        auto ref A args,
    )
{
    import reggae.rules.common: objectFiles;
    import reggae.rules.d: dlink;
    import reggae.types: TargetName, CompilerFlags, LinkerFlags, ImportPaths, StringImportPaths;
    import std.algorithm: map, joiner;
    import std.array: array;
    import std.range: chain;
    import std.traits: Unqual;

    template oneOptionalOf(T) {
        import std.meta: staticIndexOf;
        enum index = staticIndexOf!(T, A);
        static if(index == -1) {
            T oneOptionalOf() {
                return T();
            }
        } else {
            T oneOptionalOf() {
                return args[index];
            }
        }
    }
    const compilerFlags     = oneOptionalOf!CompilerFlags;
    const linkerFlags       = oneOptionalOf!LinkerFlags;
    const importPaths       = oneOptionalOf!ImportPaths;
    const stringImportPaths = oneOptionalOf!StringImportPaths;

    DubPath[] dubPaths;
    static foreach(arg; args) {
        static if(is(Unqual!(typeof(arg)) == DubPath))
            dubPaths ~= arg;
    }

    DubVersion[] dubVersions;
    static foreach(arg; args) {
        static if(is(Unqual!(typeof(arg)) == DubVersion))
            dubVersions ~= arg;
    }

    auto dubPathDependencies = dubPaths
        .map!(d => DubPathDependency(options, d))
        .array
        ;

    auto dubVersDependencies = dubVersions
        .map!(d => DubPathDependency(options, d))
        .array
        ;

    auto allImportPaths = chain(
        importPaths.value,
        dubPathDependencies.map!(d => d.dubInfo.packages.map!(p => p.importPaths).joiner).joiner,
        dubVersDependencies.map!(d => d.dubInfo.packages.map!(p => p.importPaths).joiner).joiner,
    );

    auto allStringImportPaths = chain(
        stringImportPaths.value,
        dubVersDependencies.map!(d => d.dubInfo.packages.map!(p => p.stringImportPaths).joiner).joiner,
        dubVersDependencies.map!(d => d.dubInfo.packages.map!(p => p.stringImportPaths).joiner).joiner,
    );

    auto objs = objectFiles!sourcesFunc(
        options,
        compilerFlags,
        const ImportPaths(allImportPaths),
        const StringImportPaths(allStringImportPaths),
    );

    auto dubDepsObjs = chain(
        dubPathDependencies.map!(d => d.target),
        dubVersDependencies.map!(d => d.target),
    ).array;

    const targetNameWithExt = withExtension(targetName, targetType);

    return dlink(
        TargetName(targetNameWithExt),
        objs ~ dubDepsObjs,
        linkerFlags,
    );
}

private struct DubPathDependency {
    import reggae.options: Options;
    import reggae.build: Target;
    import reggae.dub.info: DubInfo;

    string projectPath;
    Options subOptions; // options for the dub dependency
    DubInfo dubInfo;

    this(in Options reggaeOptions, in DubVersion dubVersion) {
        import std.path: buildPath;
        import std.file: exists;
        import std.process: execute;
        import std.conv: text;

        const path = buildPath(dubPkgsDir, dubVersion.name, dubVersion.version_, dubVersion.name);

        if(!path.exists) {
            const ret = execute(["dub", "fetch", dubVersion.name ~ "@" ~ dubVersion.version_]);
            if(ret.status != 0)
                throw new Exception(text("Could not fetch ", dubVersion, ": ", ret.output));
            if(!path.exists)
                throw new Exception(text("Expected path ", path, " does not exist after dub fetch"));
        }

        this(reggaeOptions, DubPath(path, dubVersion.config));
    }

    static private string dubPkgsDir() {
        import std.process: environment;
        import std.path: buildPath;

        version(Windows)
            const root = buildPath(environment["APPDATA"], "dub");
        else
            const root = buildPath(environment["HOME"], ".dub");

        return buildPath(root, "packages");
    }

    this(in Options reggaeOptions, in DubPath dubPath) {
        import reggae.dub.interop: dubInfos;
        import std.stdio: stdout;
        import std.path: buildPath;

        projectPath = reggaeOptions.projectPath;
        const path = buildPath(projectPath, dubPath.value);
        subOptions = reggaeOptions.dup;
        subOptions.projectPath = path;
        subOptions.workingDir = path;
        subOptions.dubConfig = dubPath.config.value;
        // dubInfos in this case returns an associative array but there's
        // only really one key.
        auto output = () @trusted { return stdout; }();
        dubInfo = dubInfos(output, subOptions)[dubPath.config.value];
    }

    Target target() {
        import reggae.rules.dub.runtime: dubBuild;
        import std.path: buildNormalizedPath, relativePath;
        // The complicated path manipulation below is so that we can
        // place the target in its dub directory, but relative to the
        // reggaefile's project path. The reason we use relative paths
        // instead of absolute is so the user doesn't have to type the
        // whole path to a target.

        return dubBuild(subOptions, dubInfo)
            .mapOutputs((string o) => buildNormalizedPath(
                subOptions.projectPath.relativePath(projectPath), o));
    }
}

private string withExtension(
    const imported!"reggae.types".TargetName targetName,
    DubPackageTargetType targetType,
    ) @safe pure
{
    import reggae.rules.common: exeExt, dynExt, libExt;
    import std.path: setExtension;

    final switch(targetType) with(DubPackageTargetType) {
        case executable:
            return targetName.value.setExtension(exeExt);
        case sharedLibrary:
            return targetName.value.setExtension(dynExt);
        case staticLibrary:
            return targetName.value.setExtension(libExt);
    }
}
