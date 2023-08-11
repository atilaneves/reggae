/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;


import reggae.config;
import reggae.path: buildPath;


enum CompilationMode {
    module_,  /// compile per module
    package_, /// compile per package
    all,      /// compile all source files
    options,  /// whatever the command-line option was
}

struct DubPackageName {
    string value;
}

static if(isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;
    import std.traits;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(CompilerFlags compilerFlags = CompilerFlags(),
                            LinkerFlags linkerFlags = LinkerFlags(),
                            CompilationMode compilationMode = CompilationMode.options)
        ()
    {
        import reggae.config: options;

        enum config = "default";
        enum dubInfo = configToDubInfo[config];
        enum targetName = dubInfo.targetName;
        enum linkerFlags = dubInfo.mainLinkerFlags ~ linkerFlags.value;

        return dubTarget(
            options,
            targetName,
            dubInfo,
            compilerFlags.value,
            linkerFlags,
            compilationMode,
        );
    }


    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(CompilerFlags compilerFlags = CompilerFlags(),
                         LinkerFlags linkerFlags = LinkerFlags())
                         ()
    {
        static if (__VERSION__ < 2079 || (__VERSION__ >= 2081 && __VERSION__ < 2084)) {
            // these dmd versions have a bug pertaining to separate compilation and __traits(getUnitTests),
            // we default here to compiling all-at-once for the unittest build
            enum compilationMode = CompilationMode.all;
        }
        else
            enum compilationMode = CompilationMode.options;

        return dubTestTarget!(compilerFlags, linkerFlags, compilationMode)();
    }

    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(CompilerFlags compilerFlags = CompilerFlags(),
                         LinkerFlags linkerFlags = LinkerFlags(),
                         CompilationMode compilationMode)
                         ()
    {
        import reggae.dub.info: TargetType, targetName;
        import reggae.config: options;
        import std.exception : enforce;

        // No `dub test` config? Then it inherited some `targetType "none"`, and
        // dub has printed an according message - return a dummy target and continue.
        // [Similarly, `dub test` is a no-op and returns success in such scenarios.]
        if ("unittest" !in configToDubInfo)
            return Target(null);

        const dubInfo = configToDubInfo["unittest"];
        enforce(dubInfo.packages.length, "No dub packages found for the dub test configuration");
        enforce(dubInfo.packages[0].mainSourceFile.length, "No mainSourceFile for the dub test configuration");

        auto name = dubInfo.targetName;
        const defaultDubInfo = configToDubInfo["default"];
        if (defaultDubInfo.packages.length > 0 && defaultDubInfo.targetName == name) {
            // The targetName of both default & test configs conflict (due to a bad
            // `unittest` config in dub.{sdl,json}).
            // Rename the test target to `ut[.exe]` to prevent conflicts in Ninja/make
            // build scripts (in case the default config is included in the build too).
            name = targetName(TargetType.executable, "ut");
        }

        return dubTarget(options,
                         name,
                         dubInfo,
                         compilerFlags.value,
                         linkerFlags.value,
                         compilationMode);
    }

    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(Configuration config = Configuration("default"),
                                  CompilerFlags compilerFlags = CompilerFlags(),
                                  LinkerFlags linkerFlags = LinkerFlags(),
                                  CompilationMode compilationMode = CompilationMode.options,
                                  alias objsFunction = () { Target[] t; return t; },
                                  )
        () if(isCallable!objsFunction)
    {
        import reggae.config: options;

        const dubInfo = configToDubInfo[config.value];

        return dubTarget(options,
                         dubInfo.targetName,
                         dubInfo,
                         compilerFlags.value,
                         linkerFlags.value,
                         compilationMode,
                         objsFunction());
    }

    Target dubTarget(
        TargetName targetName,
        Configuration config,
        CompilerFlags compilerFlags = CompilerFlags(),
        LinkerFlags linkerFlags = LinkerFlags(),
        CompilationMode compilationMode = CompilationMode.options,
        alias objsFunction = () { Target[] t; return t; },
     )
        ()
    {
        import reggae.config: options;

        return dubTarget(
            options,
            targetName,
            configToDubInfo[config.value],
            compilerFlags.value,
            linkerFlags.value,
            compilationMode,
            objsFunction(),
        );
    }

    Target dubTarget(
        in imported!"reggae.options".Options options,
        in TargetName targetName,
        in DubInfo dubInfo,
        in string[] compilerFlags,
        in string[] linkerFlags = [],
        in CompilationMode compilationMode = CompilationMode.options,
        Target[] extraObjects = [],
        in size_t startingIndex = 0,
        )
    {
        import reggae.rules.common: staticLibraryTarget, link;
        import reggae.types: TargetName;
        import std.path: relativePath, buildPath;

        const isStaticLibrary =
            dubInfo.targetType == TargetType.library ||
            dubInfo.targetType == TargetType.staticLibrary;
        const sharedFlags = dubInfo.targetType == TargetType.dynamicLibrary
            ? ["-shared"]
            : [];
        const allLinkerFlags = linkerFlags ~ dubInfo.linkerFlags ~ sharedFlags;
        auto allObjs = objs(targetName,
                            dubInfo,
                            compilerFlags,
                            compilationMode,
                            extraObjects,
                            startingIndex);

        const targetPath = dubInfo.targetPath(options);
        const name = realName(TargetName(buildPath(targetPath, targetName.value)), dubInfo);

        auto target = isStaticLibrary
            ? staticLibraryTarget(name, allObjs)
            : dubInfo.targetType == TargetType.none
                ? Target.phony(name, "", allObjs)
                : link(ExeName(name),
                       allObjs,
                       const Flags(allLinkerFlags));

        const combinedPostBuildCommands = dubInfo.postBuildCommands;
        return combinedPostBuildCommands.length == 0
            ? target
            : Target.phony(targetName.value ~ "_postBuild", combinedPostBuildCommands, target);
    }

    /**
       All dub packages object files from the dependencies, but nothing from the
       main package (the one actually being built).
     */
    Target[] dubDependencies(CompilerFlags compilerFlags = CompilerFlags())
        () // runtime args
    {
        return dubDependencies!(Configuration("default"), compilerFlags)();
    }


    ///ditto
    Target[] dubDependencies(Configuration config,
                             CompilerFlags compilerFlags = CompilerFlags())
        () // runtime args
    {
        const dubInfo = configToDubInfo[config.value];
        const startingIndex = 1;

        return objs(
            dubInfo.targetName,
            dubInfo,
            compilerFlags.value,
            CompilationMode.options,
            [], // extra objects
            startingIndex
        );
    }



    /**
       All dub object files for a configuration
     */
    Target[] dubObjects(Configuration config,
                        CompilerFlags compilerFlags = CompilerFlags(),
                        CompilationMode compilationMode = CompilationMode.options)
        ()
    {
        const dubInfo = configToDubInfo[config.value];
        return objs(dubInfo.targetName,
                    dubInfo,
                    compilerFlags.value,
                    compilationMode);
    }

    /**
       Object files from one dub package
     */
    Target[] dubPackageObjects(
        DubPackageName dubPackageName,
        CompilerFlags compilerFlags = CompilerFlags(),
        CompilationMode compilationMode = CompilationMode.all,
        )
        ()
    {
        return dubPackageObjects!(
            dubPackageName,
            Configuration("default"),
            compilerFlags,
            compilationMode,
        );
    }

    /**
       Object files from one dub package
     */
    Target[] dubPackageObjects(
        DubPackageName dubPackageName,
        Configuration config = Configuration("default"),
        CompilerFlags compilerFlags = CompilerFlags(),
        CompilationMode compilationMode = CompilationMode.all,
        )
        ()
    {
        return configToDubInfo[config.value].packageNameToTargets(
            dubPackageName.value,
            compilerFlags.value,
            compilationMode,
        );
    }


    ImportPaths dubImportPaths(Configuration config = Configuration("default"))() {
        return ImportPaths(configToDubInfo[config.value].allImportPaths);
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
        return link!(
            ExeName(targetName.value),
            objsFunction,
            Flags(linkerFlags.value ~ configToDubInfo[config.value].linkerFlags)
        );
    }


    /*private*/ Target[] objs(in TargetName targetName,
                          in DubInfo dubInfo,
                          in string[] compilerFlags,
                          in CompilationMode compilationMode,
                          Target[] extraObjects = [],
                          in size_t startingIndex = 0)
    {


        auto dubObjs = dubInfo.toTargets(
            compilerFlags,
            compilationMode,
            dubObjsDir(targetName, dubInfo),
            startingIndex
        );
        auto allObjs = dubObjs ~ extraObjects;

        return allObjs;
    }

    /*private*/ string realName(in TargetName targetName, in DubInfo dubInfo) {

        import std.path: buildPath;

        const path = targetName.value;

        // otherwise the target wouldn't be top-level in the presence of
        // postBuildCommands
        auto ret = dubInfo.postBuildCommands == ""
            ? path
            : buildPath("$builddir", path);

        return ret == "" ? "placeholder" : ret;
    }

    private auto dubObjsDir(in TargetName targetName, in DubInfo dubInfo) {
        import reggae.config: options;
        import reggae.dub.info: DubObjsDir;

        return DubObjsDir(
            options.dubObjsDir,
            realName(targetName, dubInfo) ~ ".objs"
        );
    }
}
