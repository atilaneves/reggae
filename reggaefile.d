import reggae;

alias main = dubMainTarget!("-g -debug");

alias utObjs = dObjects!(SrcDirs([`tests`]), Flags(`-unittest`), ImportPaths(dubInfo.targetImportPaths));
alias ut = dExeWithDubObjs!("ut", utObjs);

mixin build!(main, ut);
