import reggae;

//the actual reggae binary
//could also be dExeWithDubObjs(..., Configuration("executable"))
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias ut = dExeWithDubObjs!(ExeName("ut"), Configuration("unittest"));

mixin build!(main, ut);
