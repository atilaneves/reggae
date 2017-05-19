module tests.ut.backend.make;


import reggae;
import unit_threaded;


@("Environment variables are properly escaped")
unittest {
    import std.algorithm: canFind;
    auto make = Makefile(Build(Target("foo", "dothefoo $bla", [])), Options());
    try
        make.output.canFind("$$bla").shouldBeTrue;
    catch(UnitTestException ex) {
        writelnUt(make.output);
        throw ex;
    }
}
