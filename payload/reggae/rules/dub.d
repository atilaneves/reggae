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
}

/**
   A dub path-based dependency. The value should be a path to a dub
   package on the filesystem.
 */
struct DubPath {
    string value;
}

// outside of the static if because a project doesn't have to be a dub
// project in order to use this. There might not be a top-level
// dub.{sdl,json} but there could be dub dependencies anyway.
imported!"reggae.build".Target dubDependant(
    DubDependantTargetType targetType,
    alias sourcesFunc,
    imported!"reggae.types".CompilerFlags compilerFlags,
    DubPaths...
    )
    ()
{
    import reggae.rules.common: objectFiles, link;
    import reggae.types: ExeName, Flags, ImportPaths, StringImportPaths;
    import reggae.config: reggaeOptions = options; // the ones used to run reggae
    import std.meta: allSatisfy;
    import std.algorithm: map, joiner;
    import std.array: array;
    import std.path: buildPath;

    static assert(targetType == DubDependantTargetType.executable);
    enum isDubPath(alias T) = is(typeof(T) == DubPath);
    static assert(allSatisfy!isDubPath, DubPaths);
    static assert(DubPaths.length > 0);

    auto dubDependencies = [DubPaths]
        .map!(p => dubPathTarget(buildPath(reggaeOptions.projectPath, p.value)))
        .array;

    auto dubInfos = [DubPaths]
        .map!(p => dubInfo(buildPath(reggaeOptions.projectPath, p.value)))
        ;

    auto allImportPaths = dubInfos
        .save
        .map!(i => i.packages.map!(p => p.importPaths).joiner)
        .joiner;

    auto objs = objectFiles!sourcesFunc(
        Flags(compilerFlags.value), // FIXME - this conversion is silly
        ImportPaths(allImportPaths), // FIXME - allow the user to add to this
        StringImportPaths(), // FIXME
    );

    const targetName = "app"; // FIXME
    return link(ExeName(targetName), objs ~ dubDependencies); // FIXME: linker flags
}

private imported!"reggae.build".Target dubPathTarget(in string path) {
    import reggae.options: getOptions;
    import reggae.dub.interop: dubInfos;
    import std.stdio: stdout;

    // These options are not the same as the ones used to run reggae
    // with.  They're "sub-options" for the sole purpose of reusing
    // the dub bindings to get dub builds for dependencies.
    auto options = getOptions(
        [
            "reggae",
            "-C",
            path,
            "--dub-config=default",
            path, // not sure why I need this again with -C above...
        ]
    );

    // dubInfos in this case returns an associative array but there's
    // only really one key.
    auto dubInfo = dubInfos(stdout, options)["default"];

    return dubTarget(options, dubInfo);
}

private DubInfo dubInfo(in string path) {
    import reggae.options: getOptions;
    import reggae.dub.interop: dubInfos;
    import std.stdio: stdout;

    // These options are not the same as the ones used to run reggae
    // with.  They're "sub-options" for the sole purpose of reusing
    // the dub bindings to get dub builds for dependencies.
    auto options = getOptions(
        [
            "reggae",
            "-C",
            path,
            "--dub-config=default",
            path, // not sure why I need this again with -C above...
        ]
    );

    // dubInfos in this case returns an associative array but there's
    // only really one key.
    return dubInfos(stdout, options)["default"];
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
    import reggae.rules.common: link;
    import reggae.dub.info: TargetType;
    import reggae.types: ExeName, Flags;

        if(dubInfo.targetType == TargetType.none)
            return Target.phony(name, "", allObjs);

    const isStaticLibrary =
        dubInfo.targetType == TargetType.library ||
        dubInfo.targetType == TargetType.staticLibrary;

    const maybeStatic = isStaticLibrary
        ? ["-lib"]
        : [];
    const maybeShared = dubInfo.targetType == TargetType.dynamicLibrary
        ? ["-shared"]
        : [];

    const allLinkerFlags = dubInfo.linkerFlags ~ maybeStatic ~ maybeShared;

    return link(ExeName(name), allObjs, const Flags(allLinkerFlags));
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
