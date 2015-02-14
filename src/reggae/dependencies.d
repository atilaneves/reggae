module reggae.dependencies;


import reggae.rdmd;


string[] getImplicitDlangSrcs(in string rootModule) {
    immutable workDir = ".";
    immutable objDir = ".";
    string[] compilerFlags;

    const deps = getDependencies(rootModule, workDir, objDir, compilerFlags);
    string[] depSrcs;
    foreach(key; deps.keys) {
        if(deps[key] != "") depSrcs ~= key;
    }
    return depSrcs;
}
