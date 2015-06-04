import reggae;

//the actual reggae binary
//could also be dubConfigurationTarget(ExeName("reggae"), Configuration("executable"))
alias main = dubMainTarget!("-g -debug");

//the unit test binary
alias ut = dubConfigurationTarget!(ExeName("ut"),
                                   Configuration("unittest"),
                                   (){ Target[] t; return t;},
                                   Yes.main,
                                   Flags("-cov"));

mixin build!(main, ut);
