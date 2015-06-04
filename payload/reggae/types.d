module reggae.types;

import reggae.rules.compiler_rules: exeExt;
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
    string value;
}

struct ImportPaths {
    string[] value;
}

struct StringImportPaths {
    string[] value;
}

struct SrcDirs {
    string[] value;
}

struct SrcFiles {
    string[] value;
}

struct ExcludeFiles {
    string[] value;
}

struct ExeName {
    string value;
}

struct Configuration {
    string value = "default";
}
