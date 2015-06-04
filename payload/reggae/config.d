module reggae.config;

import reggae.dub_info;
import reggae.ctaa;

//dummy file for UT builds / flycheck
immutable string projectPath;
immutable string dflags;
immutable string reggaePath;
immutable string buildFilePath;
immutable string cCompiler = "gcc";
immutable string cppCompiler = "g++";
immutable string dCompiler = "dmd";
immutable bool perModule = true; //only for UTs, false in the real world

enum isDubProject = true;
enum dubInfo = ["default": DubInfo() ];
enum configToDubInfo = AssocList!(string, DubInfo)();
