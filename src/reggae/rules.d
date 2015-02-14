module reggae.rules;


import reggae.build;
import reggae.rdmd: objExt;
import std.path;
import std.algorithm;
import std.array;


Target dcompile(in string srcFileName, in string[] includePaths = []) {
    immutable objFileName = srcFileName.baseName.stripExtension.defaultExtension(objExt);
    immutable compiler = "dmd";
    //const implicits = getImplicitDlangSrcs(srcFileName).map!(a => Target(a)).array;
    auto cmd = compiler ~ " " ~ includePaths.map!(a => "-I$project/" ~ a).join(" ");
    cmd ~= " -c -of$out $in";
    return Target(objFileName, cmd,
                  [Target(srcFileName)],
        );
}
