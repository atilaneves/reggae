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

/**
   A target that depends on dub packages but isn't one itself.
 */
imported!"reggae.build".Target dubDependant(
    imported!"reggae.types".TargetName targetName,
    DubPackageTargetType targetType,
    alias sourcesFunc,
    // the other arguments can be:
    // * DubPath
    // * CompilerFlags
    // * LinkerFlags
    // * ImportPaths
    // * StringImportPaths
    A...
    )
    ()
{
    import reggae.rules.dub: oneOptionalOf, isOfType;
    import reggae.rules.d: dlink;
    import reggae.rules.common: objectFiles;
    import reggae.types: TargetName, CompilerFlags, LinkerFlags, ImportPaths, StringImportPaths;
    import reggae.config: reggaeOptions = options; // the ones used to run reggae
    import std.meta: Filter;
    import std.algorithm: map, joiner;
    import std.array: array;
    import std.range: chain;

    alias DubPaths = Filter!(isOfType!DubPath, A);
    static assert(DubPaths.length > 0, "At least one `DubPath` needed");

    enum compilerFlags     = oneOptionalOf!(CompilerFlags, A);
    enum linkerFlags       = oneOptionalOf!(LinkerFlags, A);
    enum importPaths       = oneOptionalOf!(ImportPaths, A);
    enum stringImportPaths = oneOptionalOf!(StringImportPaths, A);

    auto dubPathDependencies = [DubPaths]
        .map!(p => DubPathDependency(reggaeOptions, p))
        .array
        ;

    auto allImportPaths = dubPathDependencies
        .map!(d => d.dubInfo.packages.map!(p => p.importPaths).joiner)
        .joiner
        .chain(importPaths.value)
        ;

    auto allStringImportPaths = dubPathDependencies
        .map!(d => d.dubInfo.packages.map!(p => p.stringImportPaths).joiner)
        .joiner
        .chain(stringImportPaths.value)
        ;

    auto objs = objectFiles!sourcesFunc(
        compilerFlags,
        const ImportPaths(allImportPaths),
        const StringImportPaths(allStringImportPaths),
    );

    auto dubDepsObjs = dubPathDependencies
        .map!(d => d.target)
        .array
        ;

    const targetNameWithExt = withExtension(targetName, targetType);
    return dlink(
        TargetName(targetNameWithExt),
        objs ~ dubDepsObjs,
        linkerFlags,
    );
}

// mostly runtime version
imported!"reggae.build".Target dubDependant
    (alias sourcesFunc)
    (
        in imported!"reggae.options".Options options,
        in imported!"reggae.types".TargetName targetName,
        DubPackageTargetType targetType,
        in imported!"reggae.types".CompilerFlags compilerFlags,
        in imported!"reggae.types".LinkerFlags linkerFlags,
        in imported!"reggae.types".ImportPaths importPaths,
        in imported!"reggae.types".StringImportPaths stringImportPaths,
        DubPath[] dubPaths...
    )
{
    import reggae.rules.common: objectFiles;
    import reggae.rules.d: dlink;
    import reggae.types: TargetName, CompilerFlags, LinkerFlags, ImportPaths, StringImportPaths;
    import std.algorithm: map, joiner;
    import std.array: array;
    import std.range: chain;

    auto dubPathDependencies = dubPaths
        .map!(p => DubPathDependency(options, p))
        .array
        ;

    auto allImportPaths = dubPathDependencies
        .map!(d => d.dubInfo.packages.map!(p => p.importPaths).joiner)
        .joiner
        .chain(importPaths.value)
        ;

    auto allStringImportPaths = dubPathDependencies
        .map!(d => d.dubInfo.packages.map!(p => p.stringImportPaths).joiner)
        .joiner
        .chain(stringImportPaths.value)
        ;

    auto objs = objectFiles!sourcesFunc(
        compilerFlags,
        const ImportPaths(allImportPaths),
        const StringImportPaths(allStringImportPaths),
    );

    auto dubDepsObjs = dubPathDependencies
        .map!(d => d.target)
        .array
        ;

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
