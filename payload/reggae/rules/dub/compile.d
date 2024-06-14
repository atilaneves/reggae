/**
   Rules that depend on dub at compile-time, i.e. they depend on reggae.config
 */
module reggae.rules.dub.compile;


// these depend on the pre-generated reggae.config with dub information
static if(imported!"reggae.config".isDubProject) {
    import reggae.build: Target;
    import reggae.rules.dub: CompilationMode, oneOptionalOf;
    import reggae.types : Configuration;

    deprecated alias dubConfigurationTarget = dubBuild;
    deprecated alias dubDefaultTarget = dubBuild;
    deprecated alias dubTarget = dubBuild;
    deprecated alias dubTestTarget = dubTest;

    /**
       Builds a particular dub configuration (usually "default")
       Optional arguments:
       * Configuration
       * CompilationMode
       * CompilerFlags (to add to the ones from dub)
    */
    Target dubBuild(Args...)() {
        import reggae.config: options, configToDubInfo;
        import reggae.types: CompilerFlags;
        static import reggae.rules.dub.runtime;

        enum configuration      = oneOptionalOf!(Configuration  , Args);
        enum compilationMode    = oneOptionalOf!(CompilationMode, Args);
        enum extraCompilerFlags = oneOptionalOf!(CompilerFlags  , Args);

        return reggae.rules.dub.runtime.dubBuild(
            options,
            configToDubInfo,
            configuration,
            compilationMode,
            extraCompilerFlags,
        );
    }

    /**
       A target corresponding to `dub test`
     */
    Target dubTest(
        CompilationMode compilationMode = CompilationMode.options,
        imported!"std.typecons".Flag!"coverage" coverage = imported!"std.typecons".No.coverage)
        ()
    {
        import reggae.config: options, configToDubInfo;
        static import reggae.rules.dub.runtime;

        return reggae.rules.dub.runtime.dubTest(
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
        import reggae.types: LinkerFlags;

        return link!(
            targetName,
            objsFunction,
            LinkerFlags(linkerFlags.value ~ configToDubInfo[config.value].linkerFlags)
        );
    }
}
