module reggae.rules;


import reggae.build;
import std.path : baseName, stripExtension, defaultExtension;
import std.algorithm: map;
import std.array: array;

version(Windows) {
    immutable objExt = ".obj";
} else {
    immutable objExt = ".o";
}


private string objFileName(in string srcFileName) @safe pure nothrow {
    return srcFileName.baseName.stripExtension.defaultExtension(objExt);
}

Target dcompile(in string srcFileName, in string flags = "", in string[] includePaths = []) {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_dcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target cppcompile(in string srcFileName, in string flags = "", in string[] includePaths = []) {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_cppcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target ccompile(in string srcFileName, in string flags = "", in string[] includePaths = []) {
    return cppcompile(srcFileName, flags, includePaths);
}
