/**
 This file is never actually used in production. It owes its existence
 to allowing the UTs to build and flycheck to not complain.
 */

module reggae.config;

import reggae.types;

immutable string projectPath;
immutable string dflags;
immutable string ranFromPath;
immutable string buildFilePath;
immutable string cCompiler = "gcc";
immutable string cppCompiler = "g++";
immutable string dCompiler = "dmd";
immutable bool perModule = true; //only for UTs, false in the real world
immutable bool oldNinja = false;
immutable Backend backend;
enum userVars = AssocList!(string, string)();

version(minimal) {}
else {
    import reggae.dub.info;
    import reggae.ctaa;

    enum isDubProject = true;
    enum dubInfo = ["default": DubInfo() ];
    enum configToDubInfo = AssocList!(string, DubInfo)();
}
