module reggae.dub.interop.configurations;


import reggae.from;


@safe:


struct DubConfigurations {
    string[] configurations;
    string default_;
}


DubConfigurations getConfigs(O)(auto ref O output, in from!"reggae.options".Options options) {
    import reggae.dub.interop.dublib: dubConfigurations, ProjectPath, systemPackagesPath, userPackagesPath;
    return dubConfigurations(
        ProjectPath(options.projectPath),
        systemPackagesPath,
        userPackagesPath)
    ;
}
