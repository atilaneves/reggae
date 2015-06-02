import reggae;

//the actual reggae binary
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias utObjs = dObjects!(SrcDirs([`tests`]),
                         Flags(`-unittest -g -debug`),
                         ImportPaths(dubInfo.targetImportPaths ~ "src"));
alias ut = dExeWithDubObjs!("ut", utObjs);

mixin build!(main, ut);
