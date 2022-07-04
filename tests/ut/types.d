module tests.ut.types;


import reggae.types;
import unit_threaded;


@("CompilerFlags")
@trusted /* DIP100 */ pure unittest {
    static immutable expected = ["-g", "-debug"];
    CompilerFlags("-g -debug").value.should == expected;
    CompilerFlags(["-g", "-debug"]).value.should == expected;
    CompilerFlags("-g", "-debug").value.should == expected;
}
