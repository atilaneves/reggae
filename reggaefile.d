import reggae;

//the actual reggae binary
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias utObjs = dObjects!(SrcDirs([`tests`]),
                         Flags(`-unittest -g -debug`),
                         ImportPaths(dubInfo.targetImportPaths ~ "src"));
alias ut = dExeWithDubObjsConfig!(ExeName("ut"), Configuration("unittest"));

mixin build!(main, ut);
