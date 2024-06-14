module tests.ut.backend.ninja;


import reggae;
import reggae.backend.ninja;
import unit_threaded;


@Tags("ninja")
@("Environment variables are properly escaped")
unittest {
    import std.algorithm: canFind;
    auto ninja = Ninja(Build(objectFile(Options(), SourceFile("foo.d"), CompilerFlags("-I$BLA"))));
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
