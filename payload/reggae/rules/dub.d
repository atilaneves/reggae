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
     Build dub's default target, i.e. do the same as `dub build`
     */
    Target dubDefaultTarget() {
        return configToDubInfo["default"].mainTarget;
    }


    /**
     Identical to $(D dubDefaultTarget) but allows the specification
     of compiler flags (dub describe doesn't output any information)
     on the default compiler flags
    */
    Target dubDefaultTargetWithFlags(Flags flags = Flags())() {
        return configToDubInfo["default"].mainTarget(flags.value);
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

        const dubObjs = configToDubInfo[config.value].toTargets(includeMain, compilerFlags.value);
        return link(exeName.value, objsFunction() ~ dubObjs);
    }
}
