import reggae;

//the actual reggae binary
alias main = dExe!(App("src/reggae/reggae_main.d", "reggae"),
                   Flags("-g -debug"),
                   ImportPaths(["src", "payload"]),
                   StringImportPaths(["payload/reggae"]));

//the unit test binary
alias ut = dExeWithDubObjs!(ExeName("ut"), Configuration("unittest"));

mixin build!(main, ut);
