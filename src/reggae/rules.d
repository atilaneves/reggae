module reggae.rules;


import reggae.build;
import reggae.rdmd: objExt;
import reggae.dependencies;
import std.path;
import std.algorithm;
import std.array;


private string objFileName(in string srcFileName) @safe pure nothrow {
    return srcFileName.baseName.stripExtension.defaultExtension(objExt);
}

Target dcompile(in string srcFileName, in string[] includePaths = []) {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_dcompile " ~ includes,
                  [Target(srcFileName)]);
}


Target cppcompile(in string srcFileName, in string[] includePaths = []) {
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(srcFileName.objFileName, "_cppcompile " ~ includes,
                  [Target(srcFileName)]);
}
