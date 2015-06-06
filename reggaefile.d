import reggae;

//the actual reggae binary
//could also be dubConfigurationTarget(ExeName("reggae"), Configuration("executable"))
alias main = dubDefaultTargetWithFlags!(Flags("-g -debug"));

//the unit test binary
alias ut = dubConfigurationTarget!(ExeName("ut"),
                                   Configuration("unittest"),
                                   Flags("-g -debug -cov"));

mixin build!(main, ut);
