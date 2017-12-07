/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;

import reggae.config; // isDubProject

static if(isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;
    import std.typecons;
    import std.traits;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(CompilerFlags compilerFlags = CompilerFlags(),
                            LinkerFlags linkerFlags = LinkerFlags(),
                            Flag!"allTogether" allTogether = No.allTogether)
        ()
    {
        import std.string: split;

        enum config = "default";
        const dubInfo = configToDubInfo[config];
        enum targetName = dubInfo.targetName;
        enum linkerFlags = dubInfo.mainLinkerFlags ~ linkerFlags.value.split(" ");
        return dubTarget!(() { Target[] t; return t;})
            (
                targetName,
                dubInfo,
                compilerFlags.value,
                linkerFlags,
                Yes.main,
                allTogether,
            );
    }


    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(CompilerFlags compilerFlags = CompilerFlags(),
                         LinkerFlags linkerFlags = LinkerFlags())
                         ()
    {
        import std.typecons: No, Yes;
        static if (__VERSION__ >= 2077)
            enum allTogether = No.allTogether;
        else
            enum allTogether = Yes.allTogether;
        return dubTestTarget!(compilerFlags, linkerFlags, allTogether)();
    }

    /**
       A target corresponding to `dub test`
     */
    Target dubTestTarget(CompilerFlags compilerFlags = CompilerFlags(),
                         LinkerFlags linkerFlags = LinkerFlags(),
                         Flag!"allTogether" allTogether = Yes.allTogether)
                         ()
    {
        import std.string: split;

        const config = "unittest" in configToDubInfo ? "unittest" : "default";

        auto actualCompilerFlags = compilerFlags.value;
        if("unittest" !in configToDubInfo) actualCompilerFlags ~= " -unittest";

        const hasMain = configToDubInfo[config].packages[0].mainSourceFile != "";
        const extraLinkerFlags = hasMain ? [] : ["-main"];
        const actualLinkerFlags = extraLinkerFlags ~ linkerFlags.value.split(" ");

        // since dmd has a bug pertaining to separate compilation and __traits(getUnitTests),
        // we default here to compiling all-at-once for the unittest build
        return dubTarget!()(TargetName("ut"),
                            configToDubInfo[config],
                            actualCompilerFlags,
                            actualLinkerFlags,
                            Yes.main,
                            allTogether);
    }

    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(Configuration config = Configuration("default"),
                                  CompilerFlags compilerFlags = CompilerFlags(),
                                  LinkerFlags linkerFlags = LinkerFlags(),
                                  Flag!"main" includeMain = Yes.main,
                                  Flag!"allTogether" allTogether = No.allTogether,
                                  alias objsFunction = () { Target[] t; return t; },
                                  )
        () if(isCallable!objsFunction)
    {
        import std.string: split;

        const dubInfo = configToDubInfo[config.value];
        return dubTarget!objsFunction(dubInfo.targetName,
                                      dubInfo,
                                      compilerFlags.value,
                                      linkerFlags.value.split(" "),
                                      includeMain,
                                      allTogether);
    }


    Target dubTarget(alias objsFunction = () { Target[] t; return t;})
                    (in TargetName targetName,
                     in DubInfo dubInfo,
                     in string compilerFlags,
                     in string[] linkerFlags = [],
                     in Flag!"main" includeMain = Yes.main,
                     in Flag!"allTogether" allTogether = No.allTogether)
    {

        import reggae.rules.common: staticLibraryTarget;
        import std.array: join;
        import std.path: buildPath;

        const isStaticLibrary =
            dubInfo.targetType == TargetType.library ||
            dubInfo.targetType == TargetType.staticLibrary;
        const sharedFlags = dubInfo.targetType == TargetType.dynamicLibrary
            ? "-shared"
            : "";
        const allLinkerFlags = (linkerFlags ~ dubInfo.linkerFlags ~ sharedFlags).join(" ");
        auto dubObjs = dubInfo.toTargets(includeMain, compilerFlags, allTogether);
        auto allObjs = objsFunction() ~ dubObjs;

        const postBuildCommands = dubInfo.postBuildCommands;

        string realName() {
            // otherwise the target wouldn't be top-level in the presence of
            // postBuildCommands
            return postBuildCommands == ""
                ? targetName.value
                : buildPath("$project", targetName.value);
        }

        auto target = isStaticLibrary
            ? staticLibraryTarget(realName, allObjs)[0]
            : link(ExeName(realName),
                   allObjs,
                   Flags(allLinkerFlags));

        return postBuildCommands == ""
            ? target
            : Target.phony("postBuild", postBuildCommands, target);
    }
}
