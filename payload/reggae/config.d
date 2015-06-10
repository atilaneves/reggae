module reggae.config;

import reggae.types;

//dummy file for UT builds / flycheck
immutable string projectPath;
immutable string dflags;
immutable string reggaePath;
immutable string buildFilePath;
immutable string cCompiler = "gcc";
immutable string cppCompiler = "g++";
immutable string dCompiler = "dmd";
immutable bool perModule = true; //only for UTs, false in the real world
immutable Backend backend;

version(minimal) {}
else {
    import reggae.dub.info;
    import reggae.ctaa;

    enum isDubProject = true;
    enum dubInfo = ["default": DubInfo() ];
    enum configToDubInfo = AssocList!(string, DubInfo)();
}
