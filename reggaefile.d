import reggae;

Build getBuild() {
    const utObjs = dObjects!(SrcDirs([`tests`]), Flags(`-unittest`), ImportPaths(dubInfo.allImportPaths));
    const ut = dLink(`ut`, utObjs ~ dubInfo.toTargets(No.main));
    return Build(dubInfo.target, ut);
}
