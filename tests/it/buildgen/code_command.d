module tests.it.buildgen.code_command;

import tests.it.buildgen;

void func(in string[], in string[]) {  }
mixin build!(Target(`copy.txt`, &func, Target(`original.txt`)));


@("code commands should fail with backends other than binary")
@Values("ninja", "make", "tup")
@AutoTags
unittest {
    auto backend = getValue!string;
    writelnUt(backend);
    doBuildFor!(__MODULE__)(testOptions(["-b", backend, newTestDir])).
        shouldThrowWithMessage("Command type 'code' not supported for " ~ backend ~ " backend");
}
