/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;


enum CompilationMode {
    module_,  /// compile per module
    package_, /// compile per package
    all,      /// compile all source files
    options,  /// whatever the command-line option was
}

static if(imported!"reggae.config".isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;
    import std.traits;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(CompilationMode compilationMode = CompilationMode.options)
        ()
    {
        return dubConfigurationTarget!(
            Configuration("default"),
            compilationMode,
        );
    }

    Target dubDefaultTarget(C)(
        in imported!"reggae.options".Options options,
        in C configToDubInfo,
        CompilationMode compilationMode = CompilationMode.options)
    {
        enum config = "default";
        const dubInfo = configToDubInfo[config];

        return dubTarget(
            options,
            dubInfo,
            compilationMode,
        );
    }

    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(CompilationMode compilationMode = CompilationMode.options)
                         ()
    {
        import reggae.config: options, configToDubInfo;
        return dubTestTarget(
            options,
            configToDubInfo,
            compilationMode
        );
    }

    Target dubTestTarget(C)
        (in imported!"reggae.options".Options options,
        in C configToDubInfo,
        CompilationMode compilationMode = CompilationMode.options)
    {
        import reggae.build : Target;
        import reggae.rules.dub: dubTarget;
        import std.exception : enforce;

        // No `dub test` config? Then it inherited some `targetType "none"`, and
        // dub has printed an according message - return a dummy target and continue.
        // [Similarly, `dub test` is a no-op and returns success in such scenarios.]
        if ("unittest" !in configToDubInfo)
            return Target(null);

        const dubInfo = configToDubInfo["unittest"];
        enforce(dubInfo.packages.length, "No dub packages found for the dub test configuration");
        enforce(dubInfo.packages[0].mainSourceFile.length, "No mainSourceFile for the dub test configuration");

        return dubTarget(options,
                         dubInfo,
                         compilationMode);
    }

    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(Configuration config,
                                  CompilationMode compilationMode = CompilationMode.options,
                                  alias objsFunction = () { Target[] t; return t; },
                                  )
        () if(isCallable!objsFunction)
    {
        import reggae.config: options, configToDubInfo;

        const dubInfo = configToDubInfo[config.value];

        return dubTarget(options,
                         dubInfo,
                         compilationMode,
                         objsFunction());
    }

    Target dubTarget(
        in imported!"reggae.options".Options options,
        in DubInfo dubInfo,
        in CompilationMode compilationMode = CompilationMode.options,
        Target[] extraObjects = [],
        )
    {
        import reggae.rules.common: staticLibraryTarget, link;
        import std.path: buildPath;

        const isStaticLibrary =
            dubInfo.targetType == TargetType.library ||
            dubInfo.targetType == TargetType.staticLibrary;
        auto dubObjs = dubInfo.toTargets(
            compilationMode,
            dubObjsDir(options, dubInfo),
        );
        auto allObjs = dubObjs ~ extraObjects;

        const targetPath = dubInfo.targetPath(options);
        const name = realName(buildPath(targetPath, dubInfo.targetName.value), dubInfo);

        auto target = isStaticLibrary
            ? staticLibraryTarget(name, allObjs)
            : dubInfo.targetType == TargetType.none
                ? Target.phony(name, "", allObjs)
                : link(ExeName(name),
                       allObjs,
                       const Flags(dubInfo.linkerFlags));

        const combinedPostBuildCommands = dubInfo.postBuildCommands;
        return combinedPostBuildCommands.length == 0
            ? target
            : Target.phony(dubInfo.targetName.value ~ "_postBuild", combinedPostBuildCommands, target);
    }

    /**
       Link a target taking into account the dub linker flags
     */
    Target dubLink(TargetName targetName,
                   Configuration config = Configuration("default"),
                   alias objsFunction = () { Target[] t; return t; },
                   LinkerFlags linkerFlags = LinkerFlags()
        )
        ()
    {
        import reggae.config: configToDubInfo;
        return link!(
            ExeName(targetName.value),
            objsFunction,
            Flags(linkerFlags.value ~ configToDubInfo[config.value].linkerFlags)
        );
    }

    private auto dubObjsDir(in imported!"reggae.options".Options options,
                            in DubInfo dubInfo)
    {
        import reggae.dub.info: DubObjsDir;

        return DubObjsDir(
            options.dubObjsDir,
            dubInfo.targetName.value ~ ".objs",
        );
    }

    // fixes postBuildCommands, somehow
    private string realName(in string targetName, in DubInfo dubInfo) {

        import std.path: buildPath;

        // otherwise the target wouldn't be top-level in the presence of
        // postBuildCommands
        const ret = dubInfo.postBuildCommands == ""
            ? targetName
            : buildPath("$builddir", targetName);
        return ret;
    }
}
