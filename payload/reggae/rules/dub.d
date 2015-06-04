module reggae.rules.dub;

import reggae.config;

static if(isDubProject) {

    import reggae.dub_info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.d;


    Target dubDefaultTarget() {
        return configToDubInfo["default"].mainTarget;
    }


    Target dubDefaultTargetWithFlags(Flags flags = Flags())() {
        return configToDubInfo["default"].mainTarget(flags.value);
    }


    Target dubConfigurationTarget(ExeName exeName,
                                  Configuration config = Configuration("default"),
                                  Flags compilerFlags = Flags(),
                                  Flag!"main" includeMain = Yes.main,
                                  alias objsFunction = () { Target[] t; return t; },
        )() if(isCallable!objsFunction) {

            const dubObjs = configToDubInfo[config.value].toTargets(includeMain, compilerFlags.value);
            return dLink(exeName.value, objsFunction() ~ dubObjs);
        }
}
