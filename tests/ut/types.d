module tests.ut.types;


import reggae.types;
import unit_threaded;


@("CompilerFlags")
@safe pure unittest {
    static immutable expected = ["-g", "-debug"];
    CompilerFlags("-g -debug").value.should == expected;
    CompilerFlags(["-g", "-debug"]).value.should == expected;
    CompilerFlags("-g", "-debug").value.should == expected;
}
