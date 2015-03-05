import reggae;

//the actual reggae binary
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias utObjs = dObjects!(SrcDirs([`tests`]), Flags(`-unittest`), ImportPaths(dubInfo.targetImportPaths));
alias ut = dExeWithDubObjs!("ut", utObjs);

mixin build!(main, ut);
