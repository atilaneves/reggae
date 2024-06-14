/**
   Rules that depend on dub at runtime.
 */
module reggae.rules.dub.runtime;


import reggae.rules.dub: CompilationMode;
import reggae.types : Configuration;
import reggae.dub.info: DubInfo;


imported!"reggae.build".Target dubTest(C)
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

    return dubBuild(
        options,
        configToDubInfo,
        Configuration("unittest"),
        compilationMode,
        coverage ? CompilerFlags("-cov") : CompilerFlags(),
    );
}

imported!"reggae.build".Target dubBuild(C)
    (in imported!"reggae.options".Options options,
     in C configToDubInfo,
     in Configuration config = Configuration("default"),
     in CompilationMode compilationMode = CompilationMode.options,
     in imported!"reggae.types".CompilerFlags extraCompilerFlags = imported!"reggae.types".CompilerFlags())
{
    return dubBuild(
        options,
        configToDubInfo[config.value],
        compilationMode,
        extraCompilerFlags,
    );
}

imported!"reggae.build".Target dubBuild(
    in imported!"reggae.options".Options options,
    const DubInfo dubInfo,
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
    const DubInfo dubInfo,
    in string name,
    imported!"reggae.build".Target[] allObjs,
    )
    @safe pure
{
    import reggae.build: Target;
    import reggae.rules.d: dlink;
    import reggae.rules.common: link, libExt, dynExt;
    import reggae.dub.info: TargetType;
    import reggae.types: ExeName, LinkerFlags;
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

    return dlink(ExeName(name), allObjs, LinkerFlags(dubInfo.linkerFlags));
}

private auto dubObjsDir(
    in imported!"reggae.options".Options options,
    const DubInfo dubInfo)
    @safe pure
{
    import reggae.dub.info: DubObjsDir;

    return DubObjsDir(
        options.dubObjsDir,
        dubInfo.targetName.value ~ ".objs",
    );
}

// fixes postBuildCommands, somehow
private string fixNameForPostBuild(const string targetName, const DubInfo dubInfo) @safe pure {

    import std.path: buildPath;

    // otherwise the target wouldn't be top-level in the presence of
    // postBuildCommands
    const ret = dubInfo.postBuildCommands == ""
        ? targetName
        : buildPath("$builddir", targetName);
    return ret == "" ? "placeholder" : ret;
}
