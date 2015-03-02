import reggae;

Build getBuild() {
    const utObjs = dObjects!(SrcDirs([`tests`]), Flags(`-unittest`), ImportPaths(dubInfo.targetImportPaths));
    const ut = dLink(`ut`, utObjs ~ dubInfo.toTargets(No.main));
    return Build(dubInfo.mainTarget, ut);
}
