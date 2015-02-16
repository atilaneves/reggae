module reggae.dependencies;


import reggae.rdmd;
import std.path;


string[] getImplicitDlangSrcs(in string projectPath, in string rootModule) {
    immutable workDir = ".";
    immutable objDir = ".";
    string[] compilerFlags;

    const deps = getDependencies(buildPath(projectPath, rootModule), workDir, objDir, compilerFlags);
    string[] depSrcs;
    foreach(key; deps.keys) {
        if(deps[key] != "") depSrcs ~= key;
    }
    return depSrcs;
}
