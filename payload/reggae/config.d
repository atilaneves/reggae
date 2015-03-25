module reggae.config;

import reggae.dub;

//dummy file for UT builds / flycheck
immutable string projectPath;
immutable string dflags;
immutable string reggaePath;
immutable string buildFilePath;
immutable string cCompiler = "gcc";
immutable string cppCompiler = "g++";
immutable string dCompiler = "dmd";

enum dubInfo = DubInfo();
