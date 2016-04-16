module tests.it.buildgen.code_command;

import reggae;
import unit_threaded;
import tests.it;
import tests.utils;

void func(string[], string[]) {  }
mixin build!(Target(`copy.txt`, &func, Target(`original.txt`)));


//FIXME: hidden tests because of unit_threaded bug

@HiddenTest
@("code commands should fail with backends other than binary")
@Values("ninja", "make", "tup")
unittest {
    auto backend = getValue!string;
    writelnUt(backend);
    doBuildFor!(__MODULE__)(testOptions(["-b", backend])).
        shouldThrowWithMessage("Command type 'code' not supported for " ~ backend ~ " backend");
}

@HiddenTest
@("ninja", "make", "tup")
void testCommandsShouldFailWithBackendsOtherThanBinary(string backend) {
    writelnUt(backend);
    doBuildFor!(__MODULE__)(testOptions(["-b", backend])).
        shouldThrowWithMessage("Command type 'code' not supported for " ~ backend ~ " backend");

}

@("make", "ninja")
void testCommandsShouldFailWithBackend(string backend) {
    writelnUt(backend);
    doBuildFor!(__MODULE__)(testOptions(["-b", backend])).
        shouldThrowWithMessage("Command type 'code' not supported for " ~ backend ~ " backend");

}
