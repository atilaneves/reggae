/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;

import reggae.config;

static if(isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(Flags compilerFlags = Flags())() {
        return configToDubInfo["default"].mainTarget(compilerFlags.value);
    }


    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(ExeName exeName,
                                  Configuration config = Configuration("default"),
                                  Flags compilerFlags = Flags(),
                                  Flag!"main" includeMain = Yes.main,
                                  alias objsFunction = () { Target[] t; return t; },
        )() if(isCallable!objsFunction) {

        const dubInfo = configToDubInfo[config.value];
        const dubObjs = dubInfo.toTargets(includeMain, compilerFlags.value);
        const linkerFlags = dubInfo.linkerFlags().join(" ");
        return link(exeName, objsFunction() ~ dubObjs, Flags(linkerFlags));
    }

    Target dubTestTarget(Flags compilerFlags = Flags())() {

        const config = "unittest" in configToDubInfo ? "unittest" : "default";
        const actualCompilerFlags =  "unittest" in configToDubInfo ? compilerFlags.value : compilerFlags.value ~ " -unittest";
        const dubInfo =  configToDubInfo[config];
        const dubObjs = dubInfo.toTargets(Yes.main, actualCompilerFlags);
        const linkerFlags = dubInfo.linkerFlags().join(" ");
        return link(ExeName("ut"), dubObjs, Flags(linkerFlags));
    }

    /**
     All object files from a particular dub configuration (executable, unittest, etc.)
     */
    Target[] dubConfigurationObjects(Configuration config = Configuration("default"),
                                     Flags compilerFlags = Flags(),
                                     alias objsFunction = () { Target[] t; return t; },
                                     Flag!"main" includeMain = No.main)
        () if(isCallable!objsFunction) {
        return configToDubInfo[config.value].toTargets(includeMain, compilerFlags.value);
    }
}
