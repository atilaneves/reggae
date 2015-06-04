module reggae.rules.dub;

import reggae.dub_info;
import reggae.types;
import reggae.build;
import reggae.rules.compiler_rules;
import reggae.config: configToDubInfo;


Target dubDefaultTarget(string flags)() {
    return configToDubInfo["default"].mainTarget(flags);
}


Target dubConfigurationTarget(ExeName exeName,
                              Configuration config = Configuration("default"),
                              alias objsFunction = () { Target[] t; return t; },
                              Flag!"main" includeMain = Yes.main,
                              Flags compilerFlags = Flags())()
    if(isCallable!objsFunction) {

    const dubObjs = configToDubInfo[config.value].toTargets(includeMain, compilerFlags.value);
    return dLink(exeName.value, objsFunction() ~ dubObjs);
}
