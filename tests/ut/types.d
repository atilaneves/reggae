module tests.ut.types;


import reggae.types;
import unit_threaded;


@("CompilerFlags")
@safe pure unittest {
    CompilerFlags("-g -debug").value.should == "-g -debug";
    CompilerFlags(["-g", "-debug"]).value.should == "-g -debug";
    CompilerFlags("-g", "-debug").value.should == "-g -debug";
}
