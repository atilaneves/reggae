module reggae.rules;


import reggae.build;
import reggae.rdmd: objExt;
import reggae.dependencies;
import std.path;
import std.algorithm;
import std.array;


Target dcompile(in string srcFileName, in string[] includePaths = []) {
    immutable objFileName = srcFileName.baseName.stripExtension.defaultExtension(objExt);
    immutable includes = includePaths.map!(a => "-I$project/" ~ a).join(",");
    return Target(objFileName, "_dcompile " ~ includes,
                  [Target(srcFileName)]);
}
