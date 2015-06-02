import reggae;

//the actual reggae binary
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias ut = dExeWithDubObjs!(ExeName("ut"), Configuration("unittest"));

mixin build!(main, ut);
