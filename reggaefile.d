import reggae;

//the actual reggae binary
//could also be dExeWithDubObjs(ExeName("reggae"), Configuration("executable"))
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias ut = dExeWithDubObjs!(ExeName("ut"),
                            Configuration("unittest"),
                            (){ Target[] t; return t;},
                            Yes.main,
                            Flags("-cov"));

mixin build!(main, ut);
