module tests.ut.backend.ninja;


import reggae;
import unit_threaded;


@Tags("ninja")
@("Environment variables are properly escaped")
unittest {
    import std.algorithm: canFind;
    auto ninja = Ninja(Build(objectFile(SourceFile("foo.d"), Flags("-I$BLA"))));
    try
        ninja.buildOutput.canFind("$$BLA").shouldBeTrue;
    catch(UnitTestException ex) {
        writelnUt("----------------------------------------");
        writelnUt(ninja.buildOutput);
        writelnUt("----------------------------------------");
        writelnUt(ninja.rulesOutput);
        writelnUt("----------------------------------------");
        throw ex;
    }
}
