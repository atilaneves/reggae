module reggae.types;

import reggae.rules: exeExt;
import std.path: baseName, stripExtension, defaultExtension;

//Wrapper structs to ensure type-safety and readability

struct App {
    string srcFileName;
    string exeFileName;

    this(string srcFileName) @safe pure nothrow {
        immutable stripped = srcFileName.baseName.stripExtension;
        immutable exeFileName =  exeExt == "" ? stripped : stripped.defaultExtension(exeExt);

        this(srcFileName, exeFileName);
    }

    this(string srcFileName, string exeFileName) @safe pure nothrow {
        this.srcFileName = srcFileName;
        this.exeFileName = exeFileName;
    }
}


struct Flags {
    string flags;
}

struct ImportPaths {
    string[] paths;
}

struct StringImportPaths {
    string[] paths;
}

struct SrcDirs {
    string[] paths;
}

struct SrcFiles {
    string[] paths;
}

struct ExcludeFiles {
    string[] paths;
}

struct ExeName {
    string name;
}

struct Configuration {
    string config;
}
