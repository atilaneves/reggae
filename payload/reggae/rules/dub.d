/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */
module reggae.rules.dub;

// for some reason DCD don't work for this?
import reggae.dub.info: DubInfo;

enum CompilationMode {
    module_,  /// compile per module
    package_, /// compile per package
    all,      /// compile all source files
    options,  /// whatever the command-line option was
}

struct Configuration {
    string value = "default";
}

/**
   The types of binaries that a target that has dub dependencies (but
   isn't a dub package itself) can have.
 */
enum DubDependantTargetType {
    executable,
    sharedLibrary,
    staticLibrary,
}

/**
   A dub path-based dependency. The value should be a path to a dub
   package on the filesystem.
 */
struct DubPath {
    string value;
}

imported!"reggae.build".Target dubDependency(
    DubPath dubPath,
    Configuration config = Configuration(),
    )
    ()
{
    import reggae.config: reggaeOptions = options; // the ones used to run reggae
    return DubPathDependency(reggaeOptions.projectPath, dubPath, config)
        .target;
}

/**
   A target that depends on dub packages but isn't one itself.
 */
imported!"reggae.build".Target dubDependant(
    imported!"reggae.types".TargetName targetName,
    DubDependantTargetType targetType,
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
    import reggae.rules.d: dlink;
    import reggae.rules.common: objectFiles;
    import reggae.types: ExeName, CompilerFlags, LinkerFlags, Flags, ImportPaths, StringImportPaths;
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
        .map!(p => DubPathDependency(reggaeOptions.projectPath, p, Configuration()));

    auto allImportPaths = dubPathDependencies
        .save
        .map!(d => d.dubInfo.packages.map!(p => p.importPaths).joiner)
        .joiner
        .chain(importPaths.value)
        ;

    auto allStringImportPaths = dubPathDependencies
        .save
        .map!(d => d.dubInfo.packages.map!(p => p.stringImportPaths).joiner)
        .joiner
        .chain(stringImportPaths.value)
        ;

    auto objs = objectFiles!sourcesFunc(
        Flags(compilerFlags), // FIXME - this conversion is silly
        ImportPaths(allImportPaths),
        StringImportPaths(allStringImportPaths),
    );

    auto dubDepsObjs = dubPathDependencies
        .save
        .map!(d => d.target)
        .array
        ;

    const targetNameWithExt = withExtension(targetName, targetType);
    return dlink(
         // FIXME: ExeName doesn't make sense for libraries, conversion TargetName -> ExeName is silly
        ExeName(targetNameWithExt),
        objs ~ dubDepsObjs,
        Flags(linkerFlags), // FIXME: silly translation
    );
}

private template isOfType(T) {
    enum isOfType(alias A) = is(typeof(A) == T);
}

private template oneOptionalOf(T, A...) {
    import std.meta: Filter;

    alias ofType = Filter!(isOfType!T, A);
    static assert(ofType.length == 0 || ofType.length == 1,
                  "Only 0 or one of `" ~ T.stringof ~ "` allowed");

    static if(ofType.length == 0)
        enum oneOptionalOf = T();
    else
        enum oneOptionalOf = ofType[0];

}

private struct DubPathDependency {
    import reggae.options: Options;
    import reggae.build: Target;

    Options options;
    DubInfo dubInfo;

    this(in string projectPath, in DubPath dubPath, in Configuration config) {
        import reggae.dub.interop: dubInfos;
        import reggae.options: getOptions;
        import std.stdio: stdout;
        import std.path: buildPath;

        const path = buildPath(projectPath, dubPath.value);
        options = getOptions(
            [
                "reggae",
                "-C",
                path,
                "--dub-config=" ~ config.value,
                path, // not sure why I need this again with -C above...
            ]
        );
        // dubInfos in this case returns an associative array but there's
        // only really one key.
        dubInfo = dubInfos(stdout, options)[config.value];
    }

    Target target() {
        return dubTarget(options, dubInfo);
    }
}

private string withExtension(
    in imported!"reggae.types".TargetName targetName,
    DubDependantTargetType targetType,
    ) @safe pure
{
    import reggae.rules.common: exeExt, dynExt, libExt;
    import std.path: setExtension;

    final switch(targetType) with(DubDependantTargetType) {
        case executable:
            return targetName.value.setExtension(exeExt);
        case sharedLibrary:
            return targetName.value.setExtension(dynExt);
        case staticLibrary:
            return targetName.value.setExtension(libExt);
    }
}


imported!"reggae.build".Target dubTestTarget(C)
    (in imported!"reggae.options".Options options,
     in C configToDubInfo,
     in CompilationMode compilationMode = CompilationMode.options,
     in imported!"std.typecons".Flag!"coverage" coverage = imported!"std.typecons".No.coverage)
{
    import reggae.build : Target;
    import reggae.types: CompilerFlags;

    // No `dub test` config? Then it inherited some `targetType "none"`, and
    // dub has printed an according message - return a dummy target and continue.
    // [Similarly, `dub test` is a no-op and returns success in such scenarios.]
    if ("unittest" !in configToDubInfo)
        return Target(null);

    return dubTarget(
        options,
        configToDubInfo,
        Configuration("unittest"),
        compilationMode,
        coverage ? CompilerFlags("-cov") : CompilerFlags(),
    );
}

imported!"reggae.build".Target dubTarget(C)
    (in imported!"reggae.options".Options options,
     in C configToDubInfo,
     in Configuration config = Configuration("default"),
     in CompilationMode compilationMode = CompilationMode.options,
     in imported!"reggae.types".CompilerFlags extraCompilerFlags = imported!"reggae.types".CompilerFlags())
{
    return dubTarget(
        options,
        configToDubInfo[config.value],
        compilationMode,
        extraCompilerFlags,
    );
}

imported!"reggae.build".Target dubTarget(
    in imported!"reggae.options".Options options,
    in DubInfo dubInfo,
    in CompilationMode compilationMode = CompilationMode.options,
    in imported!"reggae.types".CompilerFlags extraCompilerFlags = imported!"reggae.types".CompilerFlags(),
    )
    @safe pure
{
    import reggae.build: Target;
    import std.path: buildPath;

    auto allObjs = dubInfo.toTargets(
        compilationMode,
        dubObjsDir(options, dubInfo),
        extraCompilerFlags,
    );

    const targetPath = dubInfo.targetPath(options);
    const name = fixNameForPostBuild(buildPath(targetPath, dubInfo.targetName.value), dubInfo);
    auto target = objectsToTarget(dubInfo, name, allObjs);
    const combinedPostBuildCommands = dubInfo.postBuildCommands;

    return combinedPostBuildCommands.length == 0
        ? target
        : Target.phony(dubInfo.targetName.value ~ "_postBuild", combinedPostBuildCommands, target);
}

// This function needs some explaining in case somebody (probably
// me) tries to make things "better" by removing custom logic to
// produce the final binary.  For "reasons", dub does 1 pass to
// generate static and dynamic libraries, but 2 to generate
// executables. In the former case it calls the compiler once with
// `-lib` or `-shared` as appropriate, but in the latter it first
// generates an object file then links. Reggae can't copy this
// behaviour, because dub always builds all-at-once. Since we
// support building in other ways, especially since the default
// for reggae is to build per D package, even for libraries reggae
// needs to do it in 2 steps since in the general case there will
// be multiple object files. Instead of asking dub what it does,
// we generate our own object files then link/archive.
private imported!"reggae.build".Target objectsToTarget(
    in DubInfo dubInfo,
    in string name,
    imported!"reggae.build".Target[] allObjs,
    )
    @safe pure
{
    import reggae.build: Target;
    import reggae.rules.d: dlink;
    import reggae.rules.common: link, libExt, dynExt;
    import reggae.dub.info: TargetType;
    import reggae.types: ExeName, Flags;
    import std.path: extension;

    if(dubInfo.targetType == TargetType.none)
        return Target.phony(name, "", allObjs);

    const isStaticLibrary =
        dubInfo.targetType == TargetType.library ||
        dubInfo.targetType == TargetType.staticLibrary;
    if(isStaticLibrary)
        assert(name.extension == libExt,
               "`" ~ name ~ "` does not have a static library extension`");

    if(dubInfo.targetType == TargetType.dynamicLibrary)
        assert(name.extension == dynExt,
               "`" ~ name ~ "` does not have a dynamic library extension`");

    return dlink(ExeName(name), allObjs, const Flags(dubInfo.linkerFlags));
}

private auto dubObjsDir(
    in imported!"reggae.options".Options options,
    in DubInfo dubInfo)
    @safe pure
{
    import reggae.dub.info: DubObjsDir;

    return DubObjsDir(
        options.dubObjsDir,
        dubInfo.targetName.value ~ ".objs",
    );
}

// fixes postBuildCommands, somehow
private string fixNameForPostBuild(in string targetName, in DubInfo dubInfo) @safe pure {

    import std.path: buildPath;

    // otherwise the target wouldn't be top-level in the presence of
    // postBuildCommands
    const ret = dubInfo.postBuildCommands == ""
        ? targetName
        : buildPath("$builddir", targetName);
    return ret == "" ? "placeholder" : ret;
}


// these depend on the pre-generated reggae.config with dub information
static if(imported!"reggae.config".isDubProject) {

    import reggae.build: Target;

    alias dubConfigurationTarget = dubTarget;
    alias dubDefaultTarget = dubTarget;

    /**
       Builds a particular dub configuration (usually "default")
     */
    Target dubTarget(CompilationMode compilationMode)
        ()
    {
        return dubTarget!(
            Configuration("default"),
            compilationMode,
        );
    }

    /**
       Builds a particular dub configuration (usually "default")
     */
    Target dubTarget(
        Configuration config = Configuration("default"),
        CompilationMode compilationMode = CompilationMode.options,
        )
        ()
    {
        import reggae.config: options, configToDubInfo;
        return dubTarget(options, configToDubInfo, config, compilationMode);
    }


    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(
        CompilationMode compilationMode = CompilationMode.options,
        imported!"std.typecons".Flag!"coverage" coverage = imported!"std.typecons".No.coverage)
        ()
    {
        import reggae.config: options, configToDubInfo;
        return dubTestTarget(
            options,
            configToDubInfo,
            compilationMode,
            coverage,
        );
    }


    /**
       Link a target taking into account the dub linker flags
     */
    Target dubLink(imported!"reggae.types".TargetName targetName,
                   Configuration config = Configuration("default"),
                   alias objsFunction = () { Target[] t; return t; },
                   imported!"reggae.types".LinkerFlags linkerFlags = imported!"reggae.types".LinkerFlags()
        )
        ()
    {
        import reggae.config: configToDubInfo;
        import reggae.rules.common: link;
        import reggae.types: ExeName, Flags;

        return link!(
            ExeName(targetName.value),
            objsFunction,
            Flags(linkerFlags.value ~ configToDubInfo[config.value].linkerFlags)
        );
    }
}
