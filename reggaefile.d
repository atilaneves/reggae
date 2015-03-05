import reggae;

alias utObjs = dObjects!(SrcDirs([`tests`]), Flags(`-unittest`), ImportPaths(dubInfo.targetImportPaths));
mixin build!(dubInfo.mainTarget("-g -debug"),
             () { return dLink("ut", utObjs ~ dubInfo.toTargets(No.main)); });
